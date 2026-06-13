// swift-tools-version: 5.5

import PackageDescription

let package = Package(
    name: "EditorSymbols",
    platforms: [
        .macOS(.v12),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "EditorSymbols",
            targets: ["EditorSymbols"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "EditorSymbols",
            dependencies: [],
            resources: [
                // Custom SF Symbols stored as asset catalog.
                // Paths are relative to `Sources/EditorSymbols`.
                .process("Symbols.xcassets")
            ]
        ),
        .testTarget(
            name: "EditorSymbolsTests",
            dependencies: [
                "EditorSymbols"
            ]
        ),
    ]
)
