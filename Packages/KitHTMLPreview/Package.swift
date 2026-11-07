    // swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHTMLPreview",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitHTMLPreview",
            targets: ["KitHTMLPreview"]
        )
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLocalization"),
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
