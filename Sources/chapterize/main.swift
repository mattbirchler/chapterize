import ArgumentParser
import ChapterizeKit
import Foundation

// Decided from the raw arguments so even a parse failure (an unknown flag)
// comes back as JSON when the caller asked for JSON.
let wantsJSON = CommandLine.arguments.dropFirst().contains("--json")

func fail(_ error: CLIError, staged: [RunReport.Item] = []) -> Never {
    FileHandle.standardError.write(Data(("chapterize: " + error.message + "\n").utf8))
    if wantsJSON {
        print(RunReport(error: error, staged: staged, opened: false).encodedJSON())
    }
    exit(error.exitCode)
}

do {
    let command = try ChapterizeCommand.parse()
    try command.run()
} catch let failure as ReportedFailure {
    fail(failure.error, staged: failure.staged)
} catch let error as CLIError {
    fail(error)
} catch {
    // ArgumentParser errors: help/version exit 0, parse failures exit 1.
    let exitCode = ChapterizeCommand.exitCode(for: error)
    let message = ChapterizeCommand.fullMessage(for: error)
    if exitCode.isSuccess {
        print(message)
        exit(0)
    }
    if wantsJSON {
        fail(.usage(message))
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
