import BibleCore
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    FileHandle.standardError.write(Data("Використання: bible-import <raw-dir> <out.sqlite>\n".utf8))
    exit(64)
}

let raw = URL(fileURLWithPath: arguments[1])
let output = URL(fileURLWithPath: arguments[2])
do {
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try BibleImporter.run(rawDirectory: raw, output: output)
    print("Готово: \(output.path)")
} catch {
    FileHandle.standardError.write(Data("Помилка: \(error)\n".utf8))
    exit(1)
}
