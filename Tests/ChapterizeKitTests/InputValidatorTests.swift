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

@Test func showNameAppliesToAllPlans() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let a = dir.appendingPathComponent("a.mp3")
    let b = dir.appendingPathComponent("b.mp3")
    try touch(a); try touch(b)

    let plans = try InputValidator.plans(
        audioPaths: [a.path, b.path], subtitlePath: nil, autoPairSidecars: false, showName: "Cortex")
    #expect(plans.count == 2)
    #expect(plans.allSatisfy { $0.showName == "Cortex" })
}

@Test func showNameIsTrimmedAndBlankBecomesNil() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let a = dir.appendingPathComponent("a.mp3")
    try touch(a)

    let trimmed = try InputValidator.plans(
        audioPaths: [a.path], subtitlePath: nil, autoPairSidecars: false, showName: "  Cortex  ")
    #expect(trimmed[0].showName == "Cortex")

    let blank = try InputValidator.plans(
        audioPaths: [a.path], subtitlePath: nil, autoPairSidecars: false, showName: "   ")
    #expect(blank[0].showName == nil)

    let absent = try InputValidator.plans(
        audioPaths: [a.path], subtitlePath: nil, autoPairSidecars: false)
    #expect(absent[0].showName == nil)
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

@Test func acceptsAifAndWaveExtensions() throws {
    let dir = try makeTempDir()
    defer { try? FileManager.default.removeItem(at: dir) }
    let aif = dir.appendingPathComponent("ep.aif")
    let wave = dir.appendingPathComponent("ep2.wave")
    try touch(aif); try touch(wave)

    let plans = try InputValidator.plans(
        audioPaths: [aif.path, wave.path], subtitlePath: nil, autoPairSidecars: false)
    #expect(plans.count == 2)
}

@Test func exitCodesMatchSpec() {
    #expect(CLIError.usage("x").exitCode == 1)
    #expect(CLIError.fileNotFound("x").exitCode == 1)
    #expect(CLIError.unsupportedType("x").exitCode == 1)
    #expect(CLIError.appNotInstalled.exitCode == 2)
    #expect(CLIError.stagingFailed("x").exitCode == 2)
    #expect(CLIError.openFailed("x").exitCode == 2)
}
