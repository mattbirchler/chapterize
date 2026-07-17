import AppKit
import ChapterizeKit
import Foundation

enum AppLauncher {
    static func isAppInstalled() -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: CLIInfo.appBundleID) != nil
    }

    static func openApp() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", CLIInfo.appBundleID]
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
