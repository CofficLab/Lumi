    // swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitHTMLPreview",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KitHTMLPreview",
            targets: ["KitHTMLPreview"]
        )
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
    ],

    targets: [
        .target(
            name: "KitHTMLPreview",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
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
