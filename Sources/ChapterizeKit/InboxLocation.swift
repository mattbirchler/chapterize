import Foundation

public enum InboxLocation {
    public static let appGroupID = "ZPU7B69KH3.birchtree.ChapterPod"

    public static func groupContainerURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(appGroupID, isDirectory: true)
    }

    public static func inboxURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        groupContainerURL(home: home).appendingPathComponent("Inbox", isDirectory: true)
    }

    /// Where the app writes a receipt for each drop it handled (apps after 3.0).
    public static func outboxURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        groupContainerURL(home: home).appendingPathComponent("Outbox", isDirectory: true)
    }

    public static func stagingURL(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        groupContainerURL(home: home).appendingPathComponent("Staging", isDirectory: true)
    }
}
