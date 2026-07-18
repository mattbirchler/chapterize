import Foundation

public struct StagedDrop: Equatable, Sendable {
    public let dropURL: URL
    public let manifest: InboxManifest
}

public enum Stager {
    /// Assembles the drop in Staging/<UUID>, writes manifest.json last, then
    /// atomically renames the folder into Inbox/<UUID>. The rename is the
    /// completion signal the app's directory watcher relies on, so the app
    /// only ever sees finished drops.
    public static func stage(
        _ plan: DropPlan,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        cliVersion: String = CLIInfo.version,
        now: Date = Date()
    ) throws -> StagedDrop {
        let fm = FileManager.default
        let id = UUID().uuidString
        let stagingFolder = InboxLocation.stagingURL(home: home)
            .appendingPathComponent(id, isDirectory: true)
        let inboxFolder = InboxLocation.inboxURL(home: home)
            .appendingPathComponent(id, isDirectory: true)

        do {
            try fm.createDirectory(at: stagingFolder, withIntermediateDirectories: true)
            try fm.createDirectory(at: InboxLocation.inboxURL(home: home), withIntermediateDirectories: true)

            try fm.copyItem(
                at: plan.audioURL,
                to: stagingFolder.appendingPathComponent(plan.audioURL.lastPathComponent))
            if let subtitleURL = plan.subtitleURL {
                try fm.copyItem(
                    at: subtitleURL,
                    to: stagingFolder.appendingPathComponent(subtitleURL.lastPathComponent))
            }

            let manifest = InboxManifest(
                audioFilename: plan.audioURL.lastPathComponent,
                subtitleFilename: plan.subtitleURL?.lastPathComponent,
                sourcePath: plan.audioURL.path,
                cliVersion: cliVersion,
                createdAt: now,
                showName: plan.showName)
            try manifest.encodedJSON().write(
                to: stagingFolder.appendingPathComponent("manifest.json"),
                options: .atomic)

            try fm.moveItem(at: stagingFolder, to: inboxFolder)
            return StagedDrop(dropURL: inboxFolder, manifest: manifest)
        } catch {
            try? fm.removeItem(at: stagingFolder)
            throw CLIError.stagingFailed(
                "\(error.localizedDescription) If macOS asked whether to allow access to data from other apps, allow it and run the command again. If you previously denied that prompt, turn it back on in System Settings under Privacy and Security, App Management, then retry.")
        }
    }
}
