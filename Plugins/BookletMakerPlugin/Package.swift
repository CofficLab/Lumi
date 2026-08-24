// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BookletMakerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(
            name: "BookletMakerPlugin",
            targets: ["BookletMakerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ProviderActivityBar"),
        .package(path: "../../Packages/ProviderContentView"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderRailView"),
        .package(path: "../../Packages/ProviderStorage"),
        .package(path: "../../Packages/ProviderToolbar"),
        .package(path: "../../Packages/ProviderWorkspace"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
        .target(
            name: "BookletMakerPlugin",
            dependencies: [
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderRailView", package: "ProviderRailView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "ProviderToolbar", package: "ProviderToolbar"),
                .product(name: "ProviderWorkspace", package: "ProviderWorkspace"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "BookletMakerPluginTests",
            dependencies: [.target(name: "BookletMakerPlugin")],
            path: "Tests"
        )
    ]
)
