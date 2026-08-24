// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "InputPlugin", targets: ["InputPlugin"])],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/KernelCore"),
        .package(path: "../../Packages/ProviderActivityBar"),
        .package(path: "../../Packages/ProviderContentView"),
        .package(path: "../../Packages/ProviderDocsView"),
        .package(path: "../../Packages/ProviderStorage"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
.target(
            name: "InputPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "KernelCore", package: "KernelCore"),
                .product(name: "ProviderActivityBar", package: "ProviderActivityBar"),
                .product(name: "ProviderContentView", package: "ProviderContentView"),
                .product(name: "ProviderDocsView", package: "ProviderDocsView"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: "Sources",
            resources: [.process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "InputPluginTests",
            dependencies: [.target(name: "InputPlugin")],
            path: "Tests"
        )
    ]
)
