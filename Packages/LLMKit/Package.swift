// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LLMKit",
            targets: ["LLMKit"]
        ),
    ],
    dependencies: [
        .package(name: "HttpKit", path: "../HttpKit"),
        .package(path: "../LumiLocalizationKit"),
    ],
    targets: [
        .target(
            name: "LLMKit",
            dependencies: [
                "HttpKit",
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "LLMKitTests",
            dependencies: ["LLMKit"],
            path: "Tests"
        ),
    ]
)
