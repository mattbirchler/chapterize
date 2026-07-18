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

    public init(
        audioFilename: String,
        subtitleFilename: String?,
        sourcePath: String,
        cliVersion: String,
        createdAt: Date,
        showName: String? = nil
    ) {
        self.schemaVersion = 1
        self.audioFilename = audioFilename
        self.subtitleFilename = subtitleFilename
        self.sourcePath = sourcePath
        self.cliVersion = cliVersion
        self.createdAt = ISO8601DateFormatter().string(from: createdAt)
        self.showName = showName
    }

    public func encodedJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}
