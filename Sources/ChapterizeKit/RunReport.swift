import Foundation

/// What `--json` prints on stdout. Success and failure share the shape so a
/// caller can always read `ok` first: on success `staged` lists every file,
/// on failure `error` says why, with a stable `code`.
public struct RunReport: Codable, Equatable, Sendable {
    public struct Item: Codable, Equatable, Sendable {
        public let audio: String
        public let subtitles: String?
        public let show: String?
        /// The inbox folder the files were handed over in. Nil on a dry run.
        public let drop: String?

        public init(audio: String, subtitles: String?, show: String?, drop: String?) {
            self.audio = audio
            self.subtitles = subtitles
            self.show = show
            self.drop = drop
        }
    }

    public struct Failure: Codable, Equatable, Sendable {
        public let code: String
        public let message: String
        public let exitCode: Int32
    }

    public let ok: Bool
    public let dryRun: Bool
    public let opened: Bool
    public let staged: [Item]
    public let error: Failure?
    public let version: String

    public init(staged: [Item], opened: Bool, dryRun: Bool = false, version: String = CLIInfo.version) {
        self.ok = true
        self.dryRun = dryRun
        self.opened = opened
        self.staged = staged
        self.error = nil
        self.version = version
    }

    public init(error: CLIError, staged: [Item] = [], opened: Bool = false, version: String = CLIInfo.version) {
        self.ok = false
        self.dryRun = false
        self.opened = opened
        self.staged = staged
        self.error = Failure(code: error.code, message: error.message, exitCode: error.exitCode)
        self.version = version
    }

    public func encodedJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(self), let text = String(data: data, encoding: .utf8) else {
            return #"{"ok":false}"#
        }
        return text
    }
}
