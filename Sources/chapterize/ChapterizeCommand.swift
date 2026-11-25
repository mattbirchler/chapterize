import ArgumentParser
import ChapterizeKit
import Foundation

struct ChapterizeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "chapterize",
        abstract: "Load audio and subtitle files into the Chapterize app.",
        discussion: """
            Copies audio files (with optional SRT or VTT subtitles) into the \
            Chapterize Mac app as new documents, then opens the app. Subtitle \
            files sitting next to an audio file with the same name are picked \
            up automatically.

            Examples:
              chapterize episode.mp3                  load, then open the app
              chapterize ep.mp3 -s ep.srt             load with a subtitle file
              chapterize ep.mp3 --show "Comfort Zone" associate with a show by name
              chapterize ep.mp3 --title "Ep 12" --chapters chapters.txt
                                                      set the title and chapters
              pbpaste | chapterize ep.mp3 --chapters -
                                                      chapters from stdin
              chapterize ep.mp3 --wait --json         wait for the import and report it
              chapterize ep.mp3 --background          load without bringing the app forward
              chapterize ep.mp3 --dry-run --json      check inputs, change nothing
              chapterize ep.mp3 --json                JSON result on stdout

            Output: progress goes to stderr, results to stdout. With --json, \
            stdout is always one JSON object, on success and on failure: read \
            "ok" first; failures carry "error" with a stable "code".

            Chapters files are TIME - Title lines (0:00 - Intro, 1:02:03 Outro) \
            or Podcasting 2.0 chapters JSON, and replace any chapters the audio \
            already has. --wait needs a Chapterize version newer than 3.0 to \
            report details; older ones report "picked_up".

            Exit codes:
              0  success
              1  bad input or usage (usage, file_not_found, unsupported_type,
                 invalid_chapters)
              2  handoff failed (app_not_installed, staging_failed, open_failed)
              3  permission_denied: macOS blocked access to the app's inbox; a
                 person has to allow it, retrying will not help
              4  import_failed (--wait): the app could not import a file
              5  timed_out (--wait): the app did not pick the files up in time;
                 they stay in its inbox and load the next time it runs
            """,
        version: CLIInfo.version
    )

    @Argument(help: "Audio files to load (mp3, m4a, mp4, m4b, wav, wave, aif, aiff).")
    var audioFiles: [String] = []

    @Option(name: [.customShort("s"), .customLong("subtitles")],
            help: "Subtitle file (srt or vtt). Only valid with a single audio file.")
    var subtitles: String?

    @Option(name: .customLong("show"),
            help: "Show name to associate the file(s) with. Matches an existing show, or is used as a label if none matches.")
    var show: String?

    @Option(name: .customLong("title"), help: "Episode title. Only valid with a single audio file.")
    var title: String?

    @Option(name: .customLong("chapters"),
            help: ArgumentHelp("Chapters file (txt or json), or - to read from stdin. Only valid with a single audio file.", valueName: "file"))
    var chapters: String?

    @Flag(name: .customLong("wait"),
          help: "Wait for the app to import each file and report what it did.")
    var wait = false

    @Option(name: .customLong("timeout"), help: "Seconds --wait waits per file (default 300).")
    var timeout: Double = 300

    @Flag(name: .customLong("no-auto-subs"),
          help: "Do not auto-pair sidecar subtitle files by basename.")
    var noAutoSubs = false

    @Flag(name: .customLong("no-open"), help: "Stage files without opening the app.")
    var noOpen = false

    @Flag(name: .customLong("background"),
          help: "Open the app without bringing it to the front.")
    var background = false

    @Flag(name: .customLong("open"), help: "Just open the app without loading files.")
    var openOnly = false

    @Flag(name: .customLong("dry-run"),
          help: "Check the inputs and print what would be loaded, without staging anything or opening the app.")
    var dryRun = false

    @Flag(name: .customLong("json"), help: "Print one machine-readable JSON object to stdout, on success and on failure.")
    var json = false

    @Flag(name: [.customShort("q"), .customLong("quiet")], help: "Suppress progress output.")
    var quiet = false

    func run() throws {
        if noOpen && openOnly {
            throw CLIError.usage("--open and --no-open cannot be combined.")
        }
        if noOpen && background {
            throw CLIError.usage("--background and --no-open cannot be combined.")
        }
        if openOnly {
            guard audioFiles.isEmpty else {
                throw CLIError.usage("--open does not take file arguments.")
            }
            if dryRun {
                emit(RunReport(staged: [], opened: false, dryRun: true))
                return
            }
            guard AppLauncher.isAppInstalled() else { throw CLIError.appNotInstalled }
            try AppLauncher.openApp(background: background)
            emit(RunReport(staged: [], opened: true))
            return
        }
        guard !audioFiles.isEmpty else {
            throw CLIError.usage("Provide at least one audio file, or use --open to just open the app.")
        }

        if dryRun && wait {
            throw CLIError.usage("--dry-run and --wait cannot be combined.")
        }
        guard timeout > 0 else {
            throw CLIError.usage("--timeout must be more than 0 seconds.")
        }
        if chapters != nil && audioFiles.count != 1 {
            throw CLIError.usage("--chapters can only be used with a single audio file.")
        }
        let chapterFile = try chapters.map { try ChapterFile.load(path: $0) }
        let plans = try InputValidator.plans(
            audioPaths: audioFiles,
            subtitlePath: subtitles,
            autoPairSidecars: !noAutoSubs,
            showName: show,
            title: title,
            chapters: chapterFile)

        if dryRun {
            emit(RunReport(staged: plans.map { item(for: $0, drop: nil) }, opened: false, dryRun: true))
            return
        }

        guard AppLauncher.isAppInstalled() else { throw CLIError.appNotInstalled }

        var staged: [RunReport.Item] = []
        for plan in plans {
            progress("Staging \(plan.audioURL.lastPathComponent)...")
            let drop = try Stager.stage(plan)
            staged.append(item(for: plan, drop: drop.dropURL.path))
        }

        if !noOpen {
            progress("Opening Chapterize...")
            do {
                try AppLauncher.openApp(background: background)
            } catch let error as CLIError {
                // The files are in the inbox and will load on the next
                // launch, so report them along with the failure.
                throw ReportedFailure(error: error, staged: staged)
            }
        }
        if wait {
            staged = waitForImports(staged)
            if let failed = staged.first(where: { $0.importStatus == "failed" }) {
                throw ReportedFailure(
                    error: .importFailed("\(URL(fileURLWithPath: failed.audio).lastPathComponent): \(failed.result?.error ?? "unknown error")"),
                    staged: staged, opened: !noOpen)
            }
            if staged.contains(where: { $0.importStatus == "pending" }) {
                throw ReportedFailure(
                    error: .timedOut("Chapterize did not pick the files up within \(Int(timeout)) seconds. They are still in its inbox and will load the next time it runs."),
                    staged: staged, opened: !noOpen)
            }
        }
        emit(RunReport(staged: staged, opened: !noOpen))
    }

    private func waitForImports(_ items: [RunReport.Item]) -> [RunReport.Item] {
        items.map { item in
            guard let drop = item.drop else { return item }
            progress("Waiting for Chapterize to import \(URL(fileURLWithPath: item.audio).lastPathComponent)...")
            let outcome = ReceiptWaiter.wait(forDropAt: URL(fileURLWithPath: drop), timeout: timeout)
            if outcome == .pickedUpWithoutReceipt {
                progress("Chapterize took the file but this version does not report details.")
            }
            return item.with(outcome: outcome)
        }
    }

    private func item(for plan: DropPlan, drop: String?) -> RunReport.Item {
        RunReport.Item(audio: plan.audioURL.path, subtitles: plan.subtitleURL?.path,
                       show: plan.showName, drop: drop, title: plan.title,
                       chapters: plan.chapters?.entries.count)
    }

    private func progress(_ text: String) {
        guard !quiet, !json else { return }
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    private func emit(_ report: RunReport) {
        if json {
            print(report.encodedJSON())
            return
        }
        guard !quiet else { return }
        if report.dryRun {
            for item in report.staged {
                var line = "Would load \(item.audio)"
                if let subs = item.subtitles { line += " with \(subs)" }
                if let show = item.show { line += " for \(show)" }
                if let title = item.title { line += " titled \"\(title)\"" }
                if let chapters = item.chapters { line += ", \(chapters) chapters" }
                print(line)
            }
            if report.staged.isEmpty { print("Would open Chapterize") }
            return
        }
        for item in report.staged {
            if let result = item.result, result.succeeded {
                print(Self.describe(result, audio: item.audio))
                continue
            }
            var line = "Loaded \(URL(fileURLWithPath: item.audio).lastPathComponent)"
            if let subs = item.subtitles { line += " with \(URL(fileURLWithPath: subs).lastPathComponent)" }
            if let show = item.show { line += " for \(show)" }
            print(line)
        }
        if report.staged.isEmpty && report.opened {
            print("Opened Chapterize")
        }
    }
}

extension ChapterizeCommand {
    /// One line for people: what the app made of the file.
    static func describe(_ result: ImportReceipt, audio: String) -> String {
        var parts = ["Imported \(URL(fileURLWithPath: audio).lastPathComponent)"]
        if let title = result.title { parts[0] += " as \"\(title)\"" }
        if let show = result.showName { parts.append(result.showMatched == true ? "show \(show)" : "labelled \(show)") }
        if let seconds = result.durationSeconds, seconds > 0 {
            let total = Int(seconds.rounded())
            parts.append(String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60))
        }
        if let count = result.chapterCount {
            let source = result.chaptersSource == "file" ? " from file" : ""
            parts.append("\(count) chapter\(count == 1 ? "" : "s")\(source)")
        }
        if let lines = result.transcriptLines, lines > 0 {
            parts.append("\(lines) transcript lines")
        } else if result.transcribing == true {
            parts.append("transcribing")
        }
        var text = parts.joined(separator: ", ")
        for warning in result.warnings ?? [] {
            text += "\n  warning: \(warning)"
        }
        return text
    }
}

/// A failure after some files were already handed over: the JSON report
/// lists them so a caller knows they will still load.
struct ReportedFailure: Error {
    let error: CLIError
    let staged: [RunReport.Item]
    var opened = false
}
