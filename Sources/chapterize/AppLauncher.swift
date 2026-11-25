import AppKit
import ChapterizeKit
import Foundation

enum AppLauncher {
    static func isAppInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: CLIInfo.appBundleID) != nil
    }

    /// Opens (or wakes) the app. In the background it launches without
    /// coming to the front, so a script never pulls focus from whatever the
    /// person is doing; the inbox watcher picks the files up either way.
    static func openApp(background: Bool = false) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = (background ? ["-g"] : []) + ["-b", CLIInfo.appBundleID]
        do {
            try process.run()
        } catch {
            throw CLIError.openFailed(error.localizedDescription)
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CLIError.openFailed("open exited with status \(process.terminationStatus)")
        }
    }
}
