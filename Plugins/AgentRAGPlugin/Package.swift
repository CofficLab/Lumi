// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentRAGPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AgentRAGPlugin",
            targets: ["AgentRAGPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiChatKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../ProjectsPlugin"),
    ],
    targets: [
        .target(
            name: "CSQLite",
            path: "Sources/CSQLite",
            publicHeadersPath: "include",
            cSettings: [
                .define("SQLITE_ENABLE_LOAD_EXTENSION")
            ]
        ),
        .target(
            name: "AgentRAGPlugin",
            dependencies: [
                "CSQLite",
                .product(name: "LumiChatKit", package: "LumiChatKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProjectsPlugin", package: "ProjectsPlugin"),
            ],
            path: "Sources",
            exclude: ["CSQLite"],
            resources: [
                .process("Localizable.xcstrings"),
                .copy("Resources/vec0.dylib")
            ]
        ),
        .testTarget(
            name: "AgentRAGPluginTests",
            dependencies: ["AgentRAGPlugin"],
            path: "Tests"
        )
    ]
)
