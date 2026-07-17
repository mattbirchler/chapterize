import Foundation

public enum CLIError: Error, Equatable {
    case usage(String)
    case fileNotFound(String)
    case unsupportedType(String)
    case appNotInstalled
    case stagingFailed(String)
    case openFailed(String)

    public var exitCode: Int32 {
        switch self {
        case .usage, .fileNotFound, .unsupportedType: return 1
        case .appNotInstalled, .stagingFailed, .openFailed: return 2
        }
    }

    public var message: String {
        switch self {
        case .usage(let detail):
            return detail
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedType(let path):
            return "Unsupported file type: \(path). Audio must be mp3, m4a, mp4, m4b, wav, or aiff; subtitles must be srt or vtt."
        case .appNotInstalled:
            return "The Chapterize app is not installed. Get it from the Mac App Store, then try again."
        case .stagingFailed(let detail):
            return "Could not hand files to Chapterize: \(detail)"
        case .openFailed(let detail):
            return "Could not open Chapterize: \(detail)"
        }
    }
}
