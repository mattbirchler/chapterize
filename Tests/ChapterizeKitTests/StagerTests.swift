import Foundation
import Testing
@testable import ChapterizeKit

private func makeFixture() throws -> (home: URL, audio: URL, subs: URL) {
    let fm = FileManager.default
    let home = fm.temporaryDirectory
        .appendingPathComponent("chapterize-home-\(UUID().uuidString)", isDirectory: true)
    let src = home.appendingPathComponent("src", isDirectory: true)
    try fm.createDirectory(at: src, withIntermediateDirectories: true)
    let audio = src.appendingPathComponent("ep.mp3")
    let subs = src.appendingPathComponent("ep.srt")
    try Data("audio".utf8).write(to: audio)
    try Data("subs".utf8).write(to: subs)
    return (home, audio, subs)
}

@Test func stagesCompleteDropIntoInbox() throws {
    let (home, audio, subs) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: home) }

    let drop = try Stager.stage(
        DropPlan(audioURL: audio, subtitleURL: subs),
        home: home, cliVersion: "1.0.0", now: Date())

    let inbox = InboxLocation.inboxURL(home: home)
    #expect(drop.dropURL.deletingLastPathComponent().path == inbox.path)
    #expect(FileManager.default.fileExists(atPath: drop.dropURL.appendingPathComponent("ep.mp3").path))
    #expect(FileManager.default.fileExists(atPath: drop.dropURL.appendingPathComponent("ep.srt").path))

    let manifestData = try Data(contentsOf: drop.dropURL.appendingPathComponent("manifest.json"))
    let manifest = try JSONDecoder().decode(InboxManifest.self, from: manifestData)
    #expect(manifest.audioFilename == "ep.mp3")
    #expect(manifest.subtitleFilename == "ep.srt")
    #expect(manifest.sourcePath == audio.path)

    // Staging area holds no leftovers after a successful stage.
    let stagingContents = (try? FileManager.default.contentsOfDirectory(
        atPath: InboxLocation.stagingURL(home: home).path)) ?? []
    #expect(stagingContents.isEmpty)
}

@Test func stagesAudioOnlyDrop() throws {
    let (home, audio, _) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: home) }

    let drop = try Stager.stage(
        DropPlan(audioURL: audio, subtitleURL: nil),
        home: home, cliVersion: "1.0.0", now: Date())
    #expect(drop.manifest.subtitleFilename == nil)
    let contents = try FileManager.default.contentsOfDirectory(atPath: drop.dropURL.path).sorted()
    #expect(contents == ["ep.mp3", "manifest.json"])
}

@Test func distinctDropsGetDistinctFolders() throws {
    let (home, audio, _) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: home) }

    let plan = DropPlan(audioURL: audio, subtitleURL: nil)
    let a = try Stager.stage(plan, home: home, cliVersion: "1.0.0", now: Date())
    let b = try Stager.stage(plan, home: home, cliVersion: "1.0.0", now: Date())
    #expect(a.dropURL != b.dropURL)
}

@Test func unreadableAudioThrowsStagingFailed() throws {
    let (home, audio, _) = try makeFixture()
    defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.removeItem(at: audio)

    #expect(throws: CLIError.self) {
        try Stager.stage(
            DropPlan(audioURL: audio, subtitleURL: nil),
            home: home, cliVersion: "1.0.0", now: Date())
    }
}
