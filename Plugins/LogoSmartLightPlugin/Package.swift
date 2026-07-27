// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LogoSmartLightPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "LogoSmartLightPlugin",
            targets: ["LogoSmartLightPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LocalizationKit"),    ],
    targets: [
        .target(
            name: "LogoSmartLightPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        )
    ]
)
