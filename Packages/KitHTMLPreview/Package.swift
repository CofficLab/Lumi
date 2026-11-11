    // swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHTMLPreview",
    defaultLocalization: "en",
    platforms: [
        .macOS("14.0"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitHTMLPreview",
            targets: ["KitHTMLPreview"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
    ],

    targets: [
        .target(
            name: "KitHTMLPreview",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources/KitHTMLPreview",
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "KitHTMLPreviewTests",
            dependencies: ["KitHTMLPreview"],
            path: "Tests"
        )
    ]
)
