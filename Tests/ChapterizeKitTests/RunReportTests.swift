import Foundation
import Testing
@testable import ChapterizeKit

/// Codes and exit statuses are a contract with scripts and agents: changing
/// one is a breaking change, so they are pinned here.
@Test func errorCodesAndExitStatusesArePinned() {
    let cases: [(CLIError, String, Int32)] = [
        (.usage("x"), "usage", 1),
        (.fileNotFound("x"), "file_not_found", 1),
        (.unsupportedType("x"), "unsupported_type", 1),
        (.invalidChapters("x"), "invalid_chapters", 1),
        (.appNotInstalled, "app_not_installed", 2),
        (.stagingFailed("x"), "staging_failed", 2),
        (.openFailed("x"), "open_failed", 2),
        (.permissionDenied("x"), "permission_denied", 3),
        (.importFailed("x"), "import_failed", 4),
        (.timedOut("x"), "timed_out", 5),
    ]
    for (error, code, exit) in cases {
        #expect(error.code == code)
        #expect(error.exitCode == exit)
    }
}

@Test func recognisesPermissionErrors() {
    #expect(CLIError.isPermissionError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)))
    #expect(CLIError.isPermissionError(NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))))
    let wrapped = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError,
                          userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))])
    #expect(CLIError.isPermissionError(wrapped))
    #expect(!CLIError.isPermissionError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)))
}

private func decode(_ text: String) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
}

@Test func successReportShape() throws {
    let report = RunReport(
        staged: [RunReport.Item(audio: "/a/ep.mp3", subtitles: "/a/ep.srt", show: "Comfort Zone", drop: "/inbox/X")],
        opened: true, version: "9.9.9")
    let json = try decode(report.encodedJSON())
    #expect(json["ok"] as? Bool == true)
    #expect(json["dryRun"] as? Bool == false)
    #expect(json["opened"] as? Bool == true)
    #expect(json["version"] as? String == "9.9.9")
    #expect(json["error"] == nil)
    let item = try #require((json["staged"] as? [[String: Any]])?.first)
    #expect(item["audio"] as? String == "/a/ep.mp3")
    #expect(item["drop"] as? String == "/inbox/X")
}

@Test func failureReportCarriesCode() throws {
    let json = try decode(RunReport(error: .permissionDenied("denied")).encodedJSON())
    #expect(json["ok"] as? Bool == false)
    let error = try #require(json["error"] as? [String: Any])
    #expect(error["code"] as? String == "permission_denied")
    #expect(error["exitCode"] as? Int == 3)
    #expect((error["message"] as? String)?.contains("System Settings") == true)
}

@Test func dryRunReportHasNoDrops() throws {
    let report = RunReport(staged: [RunReport.Item(audio: "/a/ep.mp3", subtitles: nil, show: nil, drop: nil)],
                           opened: false, dryRun: true)
    let json = try decode(report.encodedJSON())
    #expect(json["dryRun"] as? Bool == true)
    let item = try #require((json["staged"] as? [[String: Any]])?.first)
    #expect(item["drop"] == nil)
}
