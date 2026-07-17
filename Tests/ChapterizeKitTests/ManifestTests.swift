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
