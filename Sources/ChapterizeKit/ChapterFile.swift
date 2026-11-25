import Foundation

/// A chapters file for `--chapters`, checked before anything is staged so a
/// typo fails here, with exit code 1, instead of quietly in the app.
///
/// Two formats, the same ones the app imports:
/// - Podcasting 2.0 chapters JSON (`{"chapters":[{"startTime":0,"title":"..."}]}`)
/// - `TIME - Title` lines (`0:00 - Intro`, `12:30: News`, `1:02:03 Outro`),
///   the text Import from Text accepts. Lines that do not parse are skipped,
///   exactly as the app skips them.
public struct ChapterFile: Equatable, Sendable {
    public enum Format: String, Sendable {
        case json
        case text

        /// Name of the file inside the drop. Fixed, so it can never collide
        /// with the audio or subtitle file's name.
        public var dropFilename: String { self == .json ? "chapters.json" : "chapters.txt" }
    }

    public struct Entry: Equatable, Sendable {
        public let startTime: TimeInterval
        public let title: String
    }

    public let data: Data
    public let format: Format
    public let entries: [Entry]
    /// Where it came from: a path, or "-" for stdin.
    public let source: String

    public static let fileExtensions: Set<String> = ["txt", "text", "json"]

    /// Reads a chapters file from disk, or from stdin when `path` is "-".
    public static func load(path: String, stdin: () -> Data = { FileHandle.standardInput.readDataToEndOfFile() }) throws -> ChapterFile {
        if path == "-" {
            return try parse(stdin(), source: "-", format: nil)
        }
        let url = InputValidator.resolved(path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CLIError.fileNotFound(url.path)
        }
        let ext = url.pathExtension.lowercased()
        guard fileExtensions.contains(ext) else {
            throw CLIError.unsupportedType(url.path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CLIError.invalidChapters("\(url.path): \(error.localizedDescription)")
        }
        return try parse(data, source: url.path, format: ext == "json" ? .json : .text)
    }

    /// Parses chapters data. With no format given (stdin), JSON is detected
    /// by a leading `{`.
    public static func parse(_ data: Data, source: String, format: Format?) throws -> ChapterFile {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CLIError.invalidChapters("\(source) is not UTF-8 text.")
        }
        let resolvedFormat = format
            ?? (text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{") ? .json : .text)

        let entries: [Entry]
        switch resolvedFormat {
        case .json:
            entries = try jsonEntries(data, source: source)
        case .text:
            entries = textEntries(text)
            guard !entries.isEmpty else {
                throw CLIError.invalidChapters("\(source) has no lines like \"0:00 - Intro\".")
            }
        }
        return ChapterFile(data: data, format: resolvedFormat, entries: entries, source: source)
    }

    private struct JSONFile: Decodable {
        struct Chapter: Decodable {
            let startTime: TimeInterval
            let title: String?
            let toc: Bool?
        }
        let chapters: [Chapter]
    }

    private static func jsonEntries(_ data: Data, source: String) throws -> [Entry] {
        let file: JSONFile
        do {
            file = try JSONDecoder().decode(JSONFile.self, from: data)
        } catch {
            throw CLIError.invalidChapters("\(source) is not Podcasting 2.0 chapters JSON (an object with a \"chapters\" array of {\"startTime\", \"title\"}).")
        }
        let entries = file.chapters
            .filter { $0.toc != false }
            .map { Entry(startTime: $0.startTime, title: $0.title ?? "Untitled") }
            .sorted { $0.startTime < $1.startTime }
        guard !entries.isEmpty else {
            throw CLIError.invalidChapters("\(source) has an empty \"chapters\" array.")
        }
        return entries
    }

    // Same pattern as the app's TextChapterService.
    private static let linePattern = try! NSRegularExpression(pattern: #"^(\d+:\d{2}(?::\d{2})?)\s*[-:]?\s*(.+)$"#)

    static func textEntries(_ text: String) -> [Entry] {
        var entries: [Entry] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard let match = linePattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                  let timeRange = Range(match.range(at: 1), in: line),
                  let titleRange = Range(match.range(at: 2), in: line),
                  let time = seconds(String(line[timeRange]))
            else { continue }
            let title = line[titleRange].trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            entries.append(Entry(startTime: time, title: title))
        }
        // Stable, like the app: equal times keep their order.
        return entries.enumerated()
            .sorted { $0.element.startTime == $1.element.startTime ? $0.offset < $1.offset : $0.element.startTime < $1.element.startTime }
            .map(\.element)
    }

    static func seconds(_ time: String) -> TimeInterval? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        switch parts.count {
        case 2: return TimeInterval(parts[0] * 60 + parts[1])
        case 3: return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
        default: return nil
        }
    }
}
