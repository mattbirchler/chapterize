import Foundation
import Testing
@testable import ChapterizeKit

private func makeTempDir() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("chapterize-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}

private func touch(_ url: URL) throws {
    try Data("x".utf8).write(to: url)
}

@Test func acceptsAudioWithExplicitSubtitle() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let audio = dir.appendingPathComponent("ep.mp3")
    let subs = dir.appendingPathComponent("other.vtt")
    try touch(audio); try touch(subs)

    let plans = try InputValidator.plans(
        audioPaths: [audio.path], subtitlePath: subs.path, autoPairSidecars: true)
    #expect(plans.count == 1)
    #expect(plans[0].audioURL.lastPathComponent == "ep.mp3")
    #expect(plans[0].subtitleURL?.lastPathComponent == "other.vtt")
}

@Test func pairsSidecarSRTOverVTT() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let audio = dir.appendingPathComponent("ep.wav")
    try touch(audio)
    try touch(dir.appendingPathComponent("ep.srt"))
    try touch(dir.appendingPathComponent("ep.vtt"))

    let plans = try InputValidator.plans(
        audioPaths: [audio.path], subtitlePath: nil, autoPairSidecars: true)
    #expect(plans[0].subtitleURL?.lastPathComponent == "ep.srt")
}

@Test func noAutoSubsSkipsSidecar() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let audio = dir.appendingPathComponent("ep.mp3")
    try touch(audio)
    try touch(dir.appendingPathComponent("ep.srt"))

    let plans = try InputValidator.plans(
        audioPaths: [audio.path], subtitlePath: nil, autoPairSidecars: false)
    #expect(plans[0].subtitleURL == nil)
}

@Test func rejectsSubtitleFlagWithMultipleAudio() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let a = dir.appendingPathComponent("a.mp3")
    let b = dir.appendingPathComponent("b.mp3")
    let s = dir.appendingPathComponent("a.srt")
    try touch(a); try touch(b); try touch(s)

    #expect(throws: CLIError.self) {
        try InputValidator.plans(
            audioPaths: [a.path, b.path], subtitlePath: s.path, autoPairSidecars: true)
    }
}

@Test func rejectsMissingFileAndBadExtensions() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let missing = dir.appendingPathComponent("nope.mp3")
    #expect(throws: CLIError.self) {
        try InputValidator.plans(audioPaths: [missing.path], subtitlePath: nil, autoPairSidecars: true)
    }

    let text = dir.appendingPathComponent("notes.txt")
    try touch(text)
    #expect(throws: CLIError.self) {
        try InputValidator.plans(audioPaths: [text.path], subtitlePath: nil, autoPairSidecars: true)
    }
}

@Test func exitCodesMatchSpec() {
    #expect(CLIError.usage("x").exitCode == 1)
    #expect(CLIError.fileNotFound("x").exitCode == 1)
    #expect(CLIError.unsupportedType("x").exitCode == 1)
    #expect(CLIError.appNotInstalled.exitCode == 2)
    #expect(CLIError.stagingFailed("x").exitCode == 2)
    #expect(CLIError.openFailed("x").exitCode == 2)
}
