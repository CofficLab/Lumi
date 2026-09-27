    // swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHTMLPreview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitHTMLPreview",
            targets: ["KitHTMLPreview"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/LumiLocalization.git", from: "1.0.0"),
    ],

    targets: [
        .target(
            name: "KitHTMLPreview",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "KitHTMLPreviewTests",
            dependencies: ["KitHTMLPreview"],
            path: "Tests"
        )
    ]
)
