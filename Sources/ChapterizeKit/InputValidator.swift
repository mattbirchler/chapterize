import Foundation

public struct DropPlan: Equatable, Sendable {
    public let audioURL: URL
    public let subtitleURL: URL?

    public init(audioURL: URL, subtitleURL: URL?) {
        self.audioURL = audioURL
        self.subtitleURL = subtitleURL
    }
}

public enum InputValidator {
    public static let audioExtensions: Set<String> = ["mp3", "m4a", "mp4", "m4b", "wav", "wave", "aif", "aiff"]
    public static let subtitleExtensions: Set<String> = ["srt", "vtt"]

    public static func plans(
        audioPaths: [String],
        subtitlePath: String?,
        autoPairSidecars: Bool
    ) throws -> [DropPlan] {
        guard !audioPaths.isEmpty else {
            throw CLIError.usage("Provide at least one audio file, or use --open to just open the app.")
        }
        if subtitlePath != nil && audioPaths.count != 1 {
            throw CLIError.usage("--subtitles can only be used with a single audio file.")
        }

        var explicitSubtitle: URL?
        if let subtitlePath {
            let url = resolved(subtitlePath)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CLIError.fileNotFound(url.path)
            }
            guard subtitleExtensions.contains(url.pathExtension.lowercased()) else {
                throw CLIError.unsupportedType(url.path)
            }
            explicitSubtitle = url
        }

        return try audioPaths.map { path in
            let url = resolved(path)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CLIError.fileNotFound(url.path)
            }
            guard audioExtensions.contains(url.pathExtension.lowercased()) else {
                throw CLIError.unsupportedType(url.path)
            }
            let subtitle = explicitSubtitle ?? (autoPairSidecars ? sidecar(for: url) : nil)
            return DropPlan(audioURL: url, subtitleURL: subtitle)
        }
    }

    static func resolved(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
    }

    static func sidecar(for audioURL: URL) -> URL? {
        let base = audioURL.deletingPathExtension()
        for ext in ["srt", "vtt"] {
            let candidate = base.appendingPathExtension(ext)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }
}
