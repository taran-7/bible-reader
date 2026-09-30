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
        // Snowball (BSD-3): en/ru stemmers for morphological search (FR-18).
        .target(name: "CSnowball", exclude: ["COPYING"]),
        .target(name: "BibleCore", dependencies: ["CSnowball", .product(name: "GRDB", package: "GRDB.swift")],
                // The translation catalog (FR-30): a module is added with a manifest line.
                resources: [.copy("Resources/translations.json"),
                            // Allowlist/blocklist and illustration adapters (FR-34): one file, no code changes.
                            .copy("Resources/illustration-sources.json")]),
        .executableTarget(name: "bible-import", dependencies: ["BibleCore"]),
        .testTarget(name: "BibleCoreTests", dependencies: ["BibleCore"]),
    ]
)
