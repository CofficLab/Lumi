// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocxReadPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DocxReadPlugin",
            targets: ["DocxReadPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/SuperLogKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiLocalizationKit"),    ],
    targets: [
        .target(
            name: "DocxReadPlugin",
            dependencies: [
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        )
    ]
)
