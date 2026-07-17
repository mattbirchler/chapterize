import Testing
@testable import ChapterizeKit

@Test func versionIsSemver() {
    let parts = CLIInfo.version.split(separator: ".")
    #expect(parts.count == 3)
    #expect(parts.allSatisfy { Int($0) != nil })
}

@Test func bundleIDMatchesApp() {
    #expect(CLIInfo.appBundleID == "birchtree.ChapterPod")
}
