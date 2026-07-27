// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppSettingsPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppSettingsPlugin",
            targets: ["AppSettingsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../AppUpdatePlugin"),
    ],
    targets: [
        .target(
            name: "AppSettingsPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "AppUpdatePlugin", package: "AppUpdatePlugin"),
            ],
            path: "Sources/AppSettingsPlugin",
            resources: [
                .process("Localizable.xcstrings")
            ]
        ),
    ]
)
