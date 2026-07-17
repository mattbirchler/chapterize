import ArgumentParser
import ChapterizeKit
import Foundation

do {
    let command = try ChapterizeCommand.parse()
    try command.run()
} catch let error as CLIError {
    FileHandle.standardError.write(Data(("chapterize: " + error.message + "\n").utf8))
    exit(error.exitCode)
} catch {
    // ArgumentParser errors: help/version exit 0, parse failures exit 1.
    let exitCode = ChapterizeCommand.exitCode(for: error)
    let message = ChapterizeCommand.fullMessage(for: error)
    if exitCode.isSuccess {
        print(message)
        exit(0)
    }
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
