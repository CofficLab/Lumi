// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectRAGPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectRAGPlugin",
            targets: ["ProjectRAGPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/ProviderIdleTime"),
        .package(path: "../../Packages/ProviderProject"),
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
            name: "ProjectRAGPlugin",
            dependencies: [
                "CSQLite",
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "ProviderIdleTime", package: "ProviderIdleTime"),
                .product(name: "ProviderProject", package: "ProviderProject"),
            ],
            path: "Sources",
            exclude: [
                "CSQLite",
                // Legacy LumiPlugin facade/UI are retained in source history only.
                // The product is now the shared V2 RAG engine consumed by PluginProjectRAG.
                "ProjectRAGPlugin.swift",
                "Core/RAGPluginRuntime.swift",
                "Core/RAGPluginService.swift",
                "Hooks",
                "Tools",
                "Views",
                "Support",
            ],
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("../Resources/vec0.dylib")
            ]
        ),
        .testTarget(
            name: "ProjectRAGPluginTests",
            dependencies: ["ProjectRAGPlugin"],
            path: "Tests",
            exclude: ["ProjectRAGPluginTests.swift"]
        )
    ]
)
