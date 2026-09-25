// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "BibleReader",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BibleCore", targets: ["BibleCore"]),
        .executable(name: "bible-import", targets: ["bible-import"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(name: "BibleCore", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .executableTarget(name: "bible-import", dependencies: ["BibleCore"]),
        .testTarget(name: "BibleCoreTests", dependencies: ["BibleCore"]),
    ]
)
