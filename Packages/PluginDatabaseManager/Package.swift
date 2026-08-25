// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginDatabaseManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginDatabaseManager",
            targets: ["DatabaseManagerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../EditorContracts"),
        .package(path: "../EditorService"),
        .package(path: "../KernelCore"),
        .package(path: "../KitAgentTool"),
        .package(path: "../ProviderContentView"),
        .package(path: "../ProviderDocsView"),
        .package(path: "../ProviderExternalFile"),
        .package(path: "../ProviderToolbar"),
        .package(path: "../ProviderToolManager"),
        .package(path: "../KitLocalization"),
        .package(path: "../LumiUI"),
        .package(path: "../KitSuperLog"),
        .package(path: "../KitKeychain"),
        .package(url: "https://github.com/vapor/mysql-nio", from: "1.9.0"),
        .package(url: "https://github.com/vapor/postgres-nio", from: "1.30.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.20.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "DatabaseManagerPlugin",
            dependencies: [
                .product(name: "EditorContracts", package: "EditorContracts"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "KitAgentTool", package: "KitAgentTool"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "KitLocalization", package: "KitLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
                "TreeSitterSQL",
                .product(name: "KitSuperLog", package: "KitSuperLog"),
                .product(name: "KitKeychain", package: "KitKeychain"),
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl"),
                .product(name: "Logging", package: "swift-log"),
            ],
            path: "Sources",
            exclude: ["TreeSitterSQL"],
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("Resources/tree-sitter-sql")
            ]
        ),
        .target(
            name: "TreeSitterSQL",
            path: "Sources/TreeSitterSQL",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("vendored-headers")]
        ),
        .testTarget(
            name: "DatabaseManagerPluginTests",
            dependencies: [
                "DatabaseManagerPlugin",
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
            ],
            path: "Tests"
        )
    ]
)
