import Foundation
import Testing
@testable import ChapterizeKit

// MARK: - Chapters files

@Test func parsesTimeTitleLinesLikeTheApp() throws {
    let text = "0:00 - Intro\n12:30: News\n\nnot a chapter\n1:02:03 Outro\n102:39 - Long\n"
    let file = try ChapterFile.parse(Data(text.utf8), source: "x", format: .text)
    #expect(file.entries.map(\.title) == ["Intro", "News", "Outro", "Long"])
    #expect(file.entries.map(\.startTime) == [0, 750, 3723, 6159])
}

@Test func parsesPodcastingChaptersJSON() throws {
    let json = #"{"version":"1.2.0","chapters":[{"startTime":95.5,"title":"News"},{"startTime":0,"title":"Intro"},{"startTime":10,"toc":false}]}"#
    let file = try ChapterFile.parse(Data(json.utf8), source: "x", format: .json)
    #expect(file.entries.map(\.title) == ["Intro", "News"])
    #expect(file.format.dropFilename == "chapters.json")
}

@Test func stdinDetectsJSONByLeadingBrace() throws {
    let json = try ChapterFile.load(path: "-", stdin: { Data(#"  {"chapters":[{"startTime":0,"title":"A"}]}"#.utf8) })
    #expect(json.format == .json)
    let text = try ChapterFile.load(path: "-", stdin: { Data("0:00 - A\n".utf8) })
    #expect(text.format == .text)
    #expect(text.source == "-")
}

@Test func rejectsChaptersFilesWithNothingUsable() {
    #expect(throws: CLIError.self) { try ChapterFile.parse(Data("hello".utf8), source: "x", format: .text) }
    #expect(throws: CLIError.self) { try ChapterFile.parse(Data(#"{"chapters":[]}"#.utf8), source: "x", format: .json) }
    #expect(throws: CLIError.self) { try ChapterFile.parse(Data("[1,2]".utf8), source: "x", format: .json) }
    #expect((try? ChapterFile.parse(Data("x".utf8), source: "x", format: .text)) == nil)
}

@Test func invalidChaptersExitWithBadInput() {
    do {
        _ = try ChapterFile.parse(Data("hello".utf8), source: "x", format: .text)
    } catch let error as CLIError {
        #expect(error.code == "invalid_chapters")
        #expect(error.exitCode == 1)
    } catch {
        Issue.record("unexpected error \(error)")
    }
}

@Test func rejectsUnknownChaptersExtension() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("chapters-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let csv = dir.appendingPathComponent("c.csv")
    try Data("0:00,Intro".utf8).write(to: csv)
    #expect(throws: CLIError.unsupportedType(csv.path)) { try ChapterFile.load(path: csv.path) }
    #expect(throws: CLIError.fileNotFound(dir.appendingPathComponent("none.txt").path)) {
        try ChapterFile.load(path: dir.appendingPathComponent("none.txt").path)
    }
}

// MARK: - Title and chapters in the drop

private func fixture() throws -> (home: URL, audio: URL, other: URL) {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent("chapterize-home-\(UUID().uuidString)")
    let src = home.appendingPathComponent("src")
    try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
    let audio = src.appendingPathComponent("ep.mp3")
    let other = src.appendingPathComponent("ep2.mp3")
    try Data("audio".utf8).write(to: audio)
    try Data("audio".utf8).write(to: other)
    return (home, audio, other)
}

@Test func stagesTitleAndChaptersIntoTheManifest() throws {
    let (home, audio, _) = try fixture()
    defer { try? FileManager.default.removeItem(at: home) }
    let chapters = try ChapterFile.parse(Data("0:00 - Intro\n".utf8), source: "x", format: .text)
    let plans = try InputValidator.plans(audioPaths: [audio.path], subtitlePath: nil, autoPairSidecars: false,
                                         title: "  Episode 12 ", chapters: chapters)
    let drop = try Stager.stage(plans[0], home: home)
    #expect(drop.manifest.title == "Episode 12")
    #expect(drop.manifest.chaptersFilename == "chapters.txt")
    let staged = try Data(contentsOf: drop.dropURL.appendingPathComponent("chapters.txt"))
    #expect(String(decoding: staged, as: UTF8.self) == "0:00 - Intro\n")
}

@Test func titleAndChaptersNeedASingleFile() throws {
    let (home, audio, other) = try fixture()
    defer { try? FileManager.default.removeItem(at: home) }
    let chapters = try ChapterFile.parse(Data("0:00 - Intro\n".utf8), source: "x", format: .text)
    #expect(throws: CLIError.self) {
        try InputValidator.plans(audioPaths: [audio.path, other.path], subtitlePath: nil, autoPairSidecars: false, title: "T")
    }
    #expect(throws: CLIError.self) {
        try InputValidator.plans(audioPaths: [audio.path, other.path], subtitlePath: nil, autoPairSidecars: false, chapters: chapters)
    }
    #expect(throws: CLIError.usage("--title cannot be empty.")) {
        try InputValidator.plans(audioPaths: [audio.path], subtitlePath: nil, autoPairSidecars: false, title: "  ")
    }
}

@Test func olderManifestShapeStillHasNoNewKeysWhenUnused() throws {
    let manifest = InboxManifest(audioFilename: "a.mp3", subtitleFilename: nil, sourcePath: "/a.mp3",
                                 cliVersion: "1.2.0", createdAt: Date())
    let json = try #require(JSONSerialization.jsonObject(with: manifest.encodedJSON()) as? [String: Any])
    #expect(json["schemaVersion"] as? Int == 1)
    #expect(json["title"] == nil)
    #expect(json["chaptersFilename"] == nil)
}

// MARK: - Waiting for the receipt

private final class FakeClock {
    var now = Date(timeIntervalSince1970: 0)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

private func dropFolder(home: URL) throws -> URL {
    let drop = InboxLocation.inboxURL(home: home).appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: drop, withIntermediateDirectories: true)
    return drop
}

@Test func returnsAndDeletesTheReceipt() throws {
    let (home, _, _) = try fixture()
    defer { try? FileManager.default.removeItem(at: home) }
    let drop = try dropFolder(home: home)
    let outbox = InboxLocation.outboxURL(home: home)
    try FileManager.default.createDirectory(at: outbox, withIntermediateDirectories: true)
    let receiptURL = outbox.appendingPathComponent("\(drop.lastPathComponent).json")
    // The app's actual shape (ChapterPod InboxReceipt), including a key the CLI does not know.
    let json = """
    {"appVersion":"3.1","chapterCount":3,"chaptersSource":"file","documentID":"D","dropID":"\(drop.lastPathComponent)",
     "durationSeconds":3600,"finishedAt":"2026-11-25T10:00:00Z","schemaVersion":1,"showMatched":true,"showName":"Comfort Zone",
     "status":"imported","title":"Ep","transcribing":false,"transcriptLines":0,"warnings":[],"futureKey":1}
    """
    try Data(json.utf8).write(to: receiptURL)

    let outcome = ReceiptWaiter.wait(forDropAt: drop, home: home, timeout: 5, sleep: { _ in })
    guard case .receipt(let receipt) = outcome else {
        Issue.record("expected a receipt, got \(outcome)")
        return
    }
    #expect(receipt.succeeded)
    #expect(receipt.chapterCount == 3)
    #expect(receipt.showMatched == true)
    #expect(!FileManager.default.fileExists(atPath: receiptURL.path))
}

@Test func olderAppPicksUpWithoutReceipt() throws {
    let (home, _, _) = try fixture()
    defer { try? FileManager.default.removeItem(at: home) }
    let drop = try dropFolder(home: home)
    try FileManager.default.removeItem(at: drop)
    let clock = FakeClock()
    let outcome = ReceiptWaiter.wait(forDropAt: drop, home: home, timeout: 300,
                                     now: { clock.now }, sleep: { clock.advance($0) })
    #expect(outcome == .pickedUpWithoutReceipt)
    #expect(clock.now.timeIntervalSince1970 < 300)
}

@Test func timesOutWhileTheDropIsStillWaiting() throws {
    let (home, _, _) = try fixture()
    defer { try? FileManager.default.removeItem(at: home) }
    let drop = try dropFolder(home: home)
    let clock = FakeClock()
    let outcome = ReceiptWaiter.wait(forDropAt: drop, home: home, timeout: 30,
                                     now: { clock.now }, sleep: { clock.advance($0) })
    #expect(outcome == .timedOut)
    #expect(clock.now.timeIntervalSince1970 >= 30)
}

@Test func waitOutcomeSetsImportStatus() {
    let item = RunReport.Item(audio: "/a.mp3", subtitles: nil, show: nil, drop: "/d")
    #expect(item.with(outcome: .timedOut).importStatus == "pending")
    #expect(item.with(outcome: .pickedUpWithoutReceipt).importStatus == "picked_up")
    let failed = item.with(outcome: .receipt(ImportReceipt(dropID: "d", status: "failed", error: "bad")))
    #expect(failed.importStatus == "failed")
    #expect(failed.result?.error == "bad")
}
