import Foundation
import Testing
@testable import ChapterizeKit

@Test func manifestRoundTrips() throws {
    let manifest = InboxManifest(
        audioFilename: "ep.mp3",
        subtitleFilename: "ep.srt",
        sourcePath: "/Users/me/ep.mp3",
        cliVersion: "1.0.0",
        createdAt: Date(timeIntervalSince1970: 1_752_800_000)
    )
    let data = try manifest.encodedJSON()
    let decoded = try JSONDecoder().decode(InboxManifest.self, from: data)
    #expect(decoded == manifest)
    #expect(decoded.schemaVersion == 1)
    #expect(decoded.createdAt.hasSuffix("Z"))
}

@Test func manifestRoundTripsShowName() throws {
    let manifest = InboxManifest(
        audioFilename: "ep.mp3",
        subtitleFilename: nil,
        sourcePath: "/Users/me/ep.mp3",
        cliVersion: "1.0.0",
        createdAt: Date(),
        showName: "Cortex"
    )
    let decoded = try JSONDecoder().decode(InboxManifest.self, from: manifest.encodedJSON())
    #expect(decoded.showName == "Cortex")
    #expect(decoded == manifest)
}

@Test func manifestOmittedShowNameIsNil() throws {
    let manifest = InboxManifest(
        audioFilename: "ep.mp3",
        subtitleFilename: nil,
        sourcePath: "/Users/me/ep.mp3",
        cliVersion: "1.0.0",
        createdAt: Date()
    )
    let decoded = try JSONDecoder().decode(InboxManifest.self, from: manifest.encodedJSON())
    #expect(decoded.showName == nil)
}

@Test func manifestDecodesLegacyJSONWithoutShowName() throws {
    // A manifest written by a pre-showName CLI must still decode.
    let legacy = """
    {"schemaVersion":1,"audioFilename":"ep.mp3","subtitleFilename":null,\
    "sourcePath":"/tmp/ep.mp3","cliVersion":"0.9.0","createdAt":"2026-07-17T10:00:00Z"}
    """
    let decoded = try JSONDecoder().decode(InboxManifest.self, from: Data(legacy.utf8))
    #expect(decoded.showName == nil)
    #expect(decoded.audioFilename == "ep.mp3")
}

@Test func manifestOmittedSubtitleIsNil() throws {
    let manifest = InboxManifest(
        audioFilename: "ep.mp3",
        subtitleFilename: nil,
        sourcePath: "/Users/me/ep.mp3",
        cliVersion: "1.0.0",
        createdAt: Date()
    )
    let decoded = try JSONDecoder().decode(InboxManifest.self, from: manifest.encodedJSON())
    #expect(decoded.subtitleFilename == nil)
}

@Test func inboxPathsLiveInGroupContainer() {
    let home = URL(fileURLWithPath: "/Users/me")
    #expect(InboxLocation.inboxURL(home: home).path ==
        "/Users/me/Library/Group Containers/ZPU7B69KH3.birchtree.ChapterPod/Inbox")
    #expect(InboxLocation.stagingURL(home: home).path ==
        "/Users/me/Library/Group Containers/ZPU7B69KH3.birchtree.ChapterPod/Staging")
}
