// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SubAgentProviderPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SubAgentProviderPlugin",
            targets: ["SubAgentProviderPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "SubAgentProviderPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                        .product(name: "LocalizationKit", package: "LocalizationKit"),
],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
    ]
)
