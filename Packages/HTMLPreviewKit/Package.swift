    // swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HTMLPreviewKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "HTMLPreviewKit",
            targets: ["HTMLPreviewKit"]
        )
    ],
    dependencies: [
        .package(path: "../LocalizationKit"),
    ],

    targets: [
        .target(
            name: "HTMLPreviewKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "HTMLPreviewKitTests",
            dependencies: ["HTMLPreviewKit"],
            path: "Tests"
        )
    ]
)
