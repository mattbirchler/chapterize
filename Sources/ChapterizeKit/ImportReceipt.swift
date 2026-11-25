import Foundation

/// The app's report on one drop, read from Outbox/<dropID>.json. Mirrors
/// ChapterPod's InboxReceipt. Everything but the id and status is optional
/// so a newer or older app's receipt still decodes.
public struct ImportReceipt: Codable, Equatable, Sendable {
    public let dropID: String
    /// "imported" or "failed".
    public let status: String
    public let error: String?
    public let documentID: String?
    public let title: String?
    public let showName: String?
    public let showMatched: Bool?
    public let durationSeconds: Double?
    public let chapterCount: Int?
    /// "file" (from --chapters), "audio" (the file's own tag or markers), or "none".
    public let chaptersSource: String?
    public let transcriptLines: Int?
    /// True when the app started an on-device transcription that is still running.
    public let transcribing: Bool?
    public let warnings: [String]?
    public let appVersion: String?
    public let finishedAt: String?

    public var succeeded: Bool { status == "imported" }

    public init(dropID: String, status: String, error: String? = nil, documentID: String? = nil,
                title: String? = nil, showName: String? = nil, showMatched: Bool? = nil,
                durationSeconds: Double? = nil, chapterCount: Int? = nil, chaptersSource: String? = nil,
                transcriptLines: Int? = nil, transcribing: Bool? = nil, warnings: [String]? = nil,
                appVersion: String? = nil, finishedAt: String? = nil) {
        self.dropID = dropID
        self.status = status
        self.error = error
        self.documentID = documentID
        self.title = title
        self.showName = showName
        self.showMatched = showMatched
        self.durationSeconds = durationSeconds
        self.chapterCount = chapterCount
        self.chaptersSource = chaptersSource
        self.transcriptLines = transcriptLines
        self.transcribing = transcribing
        self.warnings = warnings
        self.appVersion = appVersion
        self.finishedAt = finishedAt
    }
}

/// How waiting for a drop ended.
public enum WaitOutcome: Equatable, Sendable {
    /// The app reported back.
    case receipt(ImportReceipt)
    /// The app took the drop out of its inbox but never wrote a receipt: an
    /// app version from before receipts existed. The import most likely
    /// worked, but there are no details.
    case pickedUpWithoutReceipt
    /// Nothing happened in time; the drop is still in the inbox.
    case timedOut
}

public enum ReceiptWaiter {
    /// How long to keep looking for a receipt after the drop has left the
    /// inbox before concluding the app does not write them.
    public static let receiptGrace: TimeInterval = 10

    /// Polls for the receipt of the drop in `dropURL` until it appears or
    /// `timeout` passes. A receipt that is found is deleted, since it has
    /// been delivered.
    public static func wait(
        forDropAt dropURL: URL,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.25,
        now: () -> Date = Date.init,
        sleep: (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) }
    ) -> WaitOutcome {
        let fm = FileManager.default
        let id = dropURL.lastPathComponent
        let receiptURL = InboxLocation.outboxURL(home: home).appendingPathComponent("\(id).json")
        let deadline = now().addingTimeInterval(timeout)
        var pickedUpAt: Date?

        while true {
            if let data = try? Data(contentsOf: receiptURL),
               let receipt = try? JSONDecoder().decode(ImportReceipt.self, from: data) {
                try? fm.removeItem(at: receiptURL)
                return .receipt(receipt)
            }
            let current = now()
            if pickedUpAt == nil, !fm.fileExists(atPath: dropURL.path) {
                pickedUpAt = current
            }
            if let pickedUpAt, current.timeIntervalSince(pickedUpAt) >= receiptGrace {
                return .pickedUpWithoutReceipt
            }
            if current >= deadline {
                return pickedUpAt == nil ? .timedOut : .pickedUpWithoutReceipt
            }
            sleep(pollInterval)
        }
    }
}
