// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PluginTerminal",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "PluginTerminal",
            targets: ["TerminalPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/ProviderActivityBar"),
        .package(path: "../../Packages/ProviderContentView"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderProject"),
        .package(path: "../../Packages/ProviderWorkspace"),
        .package(path: "../../Packages/LocalizationKit"),        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", .upToNextMajor(from: "1.5.0")),
        .package(path: "../../Packages/TerminalCoreKit"),
    ],
    targets: [
        .target(
            name: "TerminalPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderProject", package: "ProviderProject"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "SwiftTerm", package: "SwiftTerm"),
                .product(name: "TerminalCoreKit", package: "TerminalCoreKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "TerminalPluginTests",
            dependencies: [
                "TerminalPlugin",
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
            ],
            path: "Tests"
        )
    ]
)
