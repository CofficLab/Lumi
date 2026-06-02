// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "LumiCodeEditSymbols",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "CodeEditSymbols",
            targets: ["CodeEditSymbols"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CodeEditSymbols",
            dependencies: [],
            resources: [
                // Custom SF Symbols stored as asset catalog.
                // Paths are relative to `Sources/CodeEditSymbols`.
                .process("Symbols.xcassets",
            path: "Sources")
            ]
        ),
        .testTarget(
            name: "LumiCodeEditSymbolsTests",
            dependencies: [
                "CodeEditSymbols"
            ]
        ),
    ]
)
