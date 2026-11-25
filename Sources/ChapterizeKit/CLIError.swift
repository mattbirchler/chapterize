import Foundation

public enum CLIError: Error, Equatable {
    case usage(String)
    case fileNotFound(String)
    case unsupportedType(String)
    case invalidChapters(String)
    case appNotInstalled
    case permissionDenied(String)
    case stagingFailed(String)
    case openFailed(String)
    case importFailed(String)
    case timedOut(String)

    /// Process exit status. 1 is bad input, 2 a failed handoff, 3 a macOS
    /// permission only a person can grant, 4 the app could not import, 5 the
    /// app did not report back in time. Documented in --help and the README.
    public var exitCode: Int32 {
        switch self {
        case .usage, .fileNotFound, .unsupportedType, .invalidChapters: return 1
        case .appNotInstalled, .stagingFailed, .openFailed: return 2
        case .permissionDenied: return 3
        case .importFailed: return 4
        case .timedOut: return 5
        }
    }

    /// Stable, machine-readable name for the error, used in --json output.
    /// Renaming one is a breaking change for scripts and agents.
    public var code: String {
        switch self {
        case .usage: return "usage"
        case .fileNotFound: return "file_not_found"
        case .unsupportedType: return "unsupported_type"
        case .invalidChapters: return "invalid_chapters"
        case .appNotInstalled: return "app_not_installed"
        case .permissionDenied: return "permission_denied"
        case .stagingFailed: return "staging_failed"
        case .openFailed: return "open_failed"
        case .importFailed: return "import_failed"
        case .timedOut: return "timed_out"
        }
    }

    public var message: String {
        switch self {
        case .usage(let detail):
            return detail
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .unsupportedType(let path):
            return "Unsupported file type: \(path). Audio must be mp3, m4a, mp4, m4b, wav, wave, aif, or aiff; subtitles must be srt or vtt; chapters must be txt or json."
        case .invalidChapters(let detail):
            return "Could not read the chapters file: \(detail)"
        case .appNotInstalled:
            return "The Chapterize app is not installed. Get it from the Mac App Store, then try again."
        case .permissionDenied(let detail):
            return "macOS blocked access to Chapterize's inbox (\(detail)). A person needs to allow it: approve the \"access data from other apps\" prompt, or turn the terminal app on in System Settings under Privacy and Security, App Management. Then run the command again."
        case .stagingFailed(let detail):
            return "Could not hand files to Chapterize: \(detail)"
        case .openFailed(let detail):
            return "Could not open Chapterize: \(detail)"
        case .importFailed(let detail):
            return "Chapterize could not import the file: \(detail)"
        case .timedOut(let detail):
            return detail
        }
    }

    /// True for the errors macOS raises when the app group container is off
    /// limits to this process (the privacy prompt was denied or never seen).
    public static func isPermissionError(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain,
           [NSFileWriteNoPermissionError, NSFileReadNoPermissionError].contains(ns.code) {
            return true
        }
        if ns.domain == NSPOSIXErrorDomain, [Int(EPERM), Int(EACCES)].contains(ns.code) {
            return true
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            return isPermissionError(underlying)
        }
        return false
    }
}
