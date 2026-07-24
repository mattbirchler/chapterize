import Foundation
import Testing
@testable import ChapterizeKit

/// The token must match ChapterPod's Analytics.swift so app and CLI events
/// land in the same PostHog project. If the app's token ever changes, this
/// pin fails loudly instead of the CLI silently reporting into a dead project.
@Test func tokenMatchesChapterPodProject() {
    #expect(CLIAnalytics.projectToken == "phc_ttWntAQt5WmmZXDGPyxWzq6RPeDhgHxWouZ6ncxVnYVz")
}

/// Event names feed existing dashboards; renaming one is a breaking change.
@Test func eventNamesArePinned() {
    #expect(CLIAnalytics.Action.filesLoaded.rawValue == "cli_files_loaded")
    #expect(CLIAnalytics.Action.appOpened.rawValue == "cli_app_opened")
    #expect(CLIAnalytics.Action.allCases.count == 2)
}

@Test func payloadCarriesEventAndMetadata() {
    let payload = CLIAnalytics.payload(
        action: .filesLoaded,
        distinctID: "abc",
        metadata: ["file_count": 2]
    )
    #expect(payload["api_key"] as? String == CLIAnalytics.projectToken)
    #expect(payload["event"] as? String == "cli_files_loaded")
    #expect(payload["distinct_id"] as? String == "abc")
    let properties = payload["properties"] as? [String: Any]
    #expect(properties?["file_count"] as? Int == 2)
    #expect(properties?["platform"] as? String == "cli")
    #expect(properties?["cli_version"] as? String == CLIInfo.version)
    #expect((properties?["os_version"] as? String)?.hasPrefix("macOS ") == true)
}

/// Privacy keys must survive even a hostile metadata dictionary: no location,
/// no IP, no person profile.
@Test func payloadPrivacyKeysCannotBeOverridden() {
    let payload = CLIAnalytics.payload(
        action: .appOpened,
        distinctID: "abc",
        metadata: ["$geoip_disable": false, "$ip": "1.2.3.4", "$process_person_profile": true]
    )
    let properties = payload["properties"] as? [String: Any]
    #expect(properties?["$geoip_disable"] as? Bool == true)
    #expect(properties?["$ip"] is NSNull)
    #expect(properties?["$process_person_profile"] as? Bool == false)
}

@Test func optOutRespectsBothVariables() {
    #expect(CLIAnalytics.isDisabled(environment: ["DO_NOT_TRACK": "1"]))
    #expect(CLIAnalytics.isDisabled(environment: ["CHAPTERIZE_NO_ANALYTICS": "true"]))
    #expect(!CLIAnalytics.isDisabled(environment: [:]))
    #expect(!CLIAnalytics.isDisabled(environment: ["DO_NOT_TRACK": "0"]))
    #expect(!CLIAnalytics.isDisabled(environment: ["DO_NOT_TRACK": ""]))
}

@Test func distinctIDIsStableAcrossRuns() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("chapterize-analytics-test-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let first = CLIAnalytics.persistentDistinctID(directory: directory)
    let second = CLIAnalytics.persistentDistinctID(directory: directory)
    #expect(first == second)
    #expect(!first.isEmpty)
}
