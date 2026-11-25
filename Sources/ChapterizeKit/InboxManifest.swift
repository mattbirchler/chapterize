import Foundation

public struct InboxManifest: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let audioFilename: String
    public let subtitleFilename: String?
    public let sourcePath: String
    public let cliVersion: String
    public let createdAt: String
    /// Optional show name from the `--show` flag. The app matches it to an
    /// existing show (case-insensitive) or, failing that, uses it as a label.
    public let showName: String?
    /// Optional episode title from `--title` (1.2+). Apps before the one
    /// that writes receipts ignore it.
    public let title: String?
    /// Optional chapters file in the drop from `--chapters` (1.2+), JSON or
    /// `TIME - Title` text. Replaces the chapters the audio carried.
    public let chaptersFilename: String?

    public init(
        audioFilename: String,
        subtitleFilename: String?,
        sourcePath: String,
        cliVersion: String,
        createdAt: Date,
        showName: String? = nil,
        title: String? = nil,
        chaptersFilename: String? = nil
    ) {
        self.schemaVersion = 1
        self.audioFilename = audioFilename
        self.subtitleFilename = subtitleFilename
        self.sourcePath = sourcePath
        self.cliVersion = cliVersion
        self.createdAt = ISO8601DateFormatter().string(from: createdAt)
        self.showName = showName
        self.title = title
        self.chaptersFilename = chaptersFilename
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
