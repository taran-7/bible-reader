import BibleCore
import Foundation

exit(ImportCommand.run(arguments: CommandLine.arguments) {
    FileHandle.standardError.write(Data($0.utf8))
})
