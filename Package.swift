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
        // Snowball (BSD-3): стемери en/ru для морфологічного пошуку (FR-18).
        .target(name: "CSnowball", exclude: ["COPYING"]),
        .target(name: "BibleCore", dependencies: ["CSnowball", .product(name: "GRDB", package: "GRDB.swift")],
                // Каталог перекладів (FR-30): модуль додається рядком маніфесту.
                resources: [.copy("Resources/translations.json")]),
        .executableTarget(name: "bible-import", dependencies: ["BibleCore"]),
        .testTarget(name: "BibleCoreTests", dependencies: ["BibleCore"]),
    ]
)
