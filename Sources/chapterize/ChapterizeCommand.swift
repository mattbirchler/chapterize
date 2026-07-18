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

    @Flag(name: .customLong("no-auto-subs"),
          help: "Do not auto-pair sidecar subtitle files by basename.")
    var noAutoSubs = false

    @Flag(name: .customLong("no-open"), help: "Stage files without opening the app.")
    var noOpen = false

    @Flag(name: .customLong("open"), help: "Just open the app without loading files.")
    var openOnly = false

    @Flag(name: .customLong("json"), help: "Print a machine-readable JSON summary to stdout.")
    var json = false

    @Flag(name: [.customShort("q"), .customLong("quiet")], help: "Suppress progress output.")
    var quiet = false

    func run() throws {
        if noOpen && openOnly {
            throw CLIError.usage("--open and --no-open cannot be combined.")
        }
        if openOnly {
            guard audioFiles.isEmpty else {
                throw CLIError.usage("--open does not take file arguments.")
            }
            guard AppLauncher.isAppInstalled() else { throw CLIError.appNotInstalled }
            try AppLauncher.openApp()
            emitSummary(staged: [], opened: true)
            return
        }
        guard !audioFiles.isEmpty else {
            throw CLIError.usage("Provide at least one audio file, or use --open to just open the app.")
        }
        guard AppLauncher.isAppInstalled() else { throw CLIError.appNotInstalled }

        let plans = try InputValidator.plans(
            audioPaths: audioFiles,
            subtitlePath: subtitles,
            autoPairSidecars: !noAutoSubs,
            showName: show)

        var staged: [StagedDrop] = []
        for plan in plans {
            progress("Staging \(plan.audioURL.lastPathComponent)...")
            staged.append(try Stager.stage(plan))
        }

        var opened = false
        var openError: CLIError?
        if !noOpen {
            progress("Opening Chapterize...")
            do {
                try AppLauncher.openApp()
                opened = true
            } catch let error as CLIError {
                openError = error
            }
        }
        emitSummary(staged: staged, opened: opened, plans: plans)
        if let openError { throw openError }
    }

    private func progress(_ text: String) {
        guard !quiet else { return }
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    private struct Summary: Codable {
        struct Item: Codable {
            let audio: String
            let subtitles: String?
            let show: String?
            let drop: String
        }
        let staged: [Item]
        let opened: Bool
    }

    private func emitSummary(staged: [StagedDrop], opened: Bool, plans: [DropPlan] = []) {
        if json {
            let summary = Summary(
                staged: zip(staged, plans).map { drop, plan in
                    Summary.Item(
                        audio: plan.audioURL.path,
                        subtitles: plan.subtitleURL?.path,
                        show: plan.showName,
                        drop: drop.dropURL.path)
                },
                opened: opened)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(summary), let text = String(data: data, encoding: .utf8) {
                print(text)
            }
            return
        }
        guard !quiet else { return }
        for (drop, plan) in zip(staged, plans) {
            var line = "Loaded \(drop.manifest.audioFilename)"
            if let sub = plan.subtitleURL {
                line += " with \(sub.lastPathComponent)"
            }
            if let show = plan.showName {
                line += " for \(show)"
            }
            print(line)
        }
        if staged.isEmpty && opened {
            print("Opened Chapterize")
        }
    }
}
