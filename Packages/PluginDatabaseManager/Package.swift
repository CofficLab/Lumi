// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDatabaseManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "PluginDatabaseManager",
            targets: ["DatabaseManagerPlugin"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiProviders.git", from: "1.12.0"),
        .package(path: "../ProviderEditor"),
        .package(path: "../PluginCodeEditorHost"),
        .package(url: "https://github.com/CofficLab/LumiKernel.git", from: "1.1.0"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderChatSection"),
        .package(path: "../ProviderExternalFile"),
        .package(path: "../ProviderToolManager"),
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.11.1"),
        .package(url: "https://github.com/CofficLab/LumiLogging.git", from: "1.0.1"),
        .package(path: "../KitKeychain"),
        .package(url: "https://github.com/vapor/mysql-nio", from: "1.9.2"),
        .package(url: "https://github.com/vapor/postgres-nio", from: "1.33.2"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.104.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.37.5"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.16.2"),
    ],
    targets: [
        .target(
            name: "DatabaseManagerPlugin",
            dependencies: [
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderDocsView", package: "LumiProviders"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderStorage", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                "TreeSitterSQL",
                .product(name: "LumiLoggingKit", package: "LumiLogging"),
                .product(name: "KitKeychain", package: "KitKeychain"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources/PluginDatabaseManager",
            exclude: ["TreeSitterSQL"],
            resources: [
                .process("../../Resources/Localizable.xcstrings"),
                .copy("../../Resources/tree-sitter-sql")
            ]
        ),
        .target(
            name: "TreeSitterSQL",
            path: "Sources/PluginDatabaseManager/TreeSitterSQL",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("vendored-headers")]
        ),
        .testTarget(
            name: "DatabaseManagerPluginTests",
            dependencies: [
                "DatabaseManagerPlugin",
                .product(name: "ProviderEditor", package: "ProviderEditor"),
                .product(name: "PluginCodeEditorHost", package: "PluginCodeEditorHost"),
                .product(name: "KernelCore", package: "LumiKernel"),
                .product(name: "ProviderActivityBar", package: "LumiProviders"),
                .product(name: "ProviderChatSection", package: "ProviderChatSection"),
                .product(name: "ProviderContentView", package: "LumiProviders"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
                .product(name: "ProviderRailView", package: "LumiProviders"),
                .product(name: "ProviderRootView", package: "LumiProviders"),
                .product(name: "ProviderToolbar", package: "LumiProviders"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests"
        )
    ]
)
