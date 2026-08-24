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
        .package(path: "../../Packages/EditorContracts"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/ProviderContentView"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderExternalFile"),
        .package(path: "../../Packages/ProviderToolbar"),
        .package(path: "../../Packages/ProviderToolManager"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/KeychainKit"),
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
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderExternalFile", package: "ProviderExternalFile"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderToolManager", package: "ProviderToolManager"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                "TreeSitterSQL",
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "KeychainKit", package: "KeychainKit"),
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
