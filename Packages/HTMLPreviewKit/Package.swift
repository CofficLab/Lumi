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
    targets: [
        .target(
            name: "HTMLPreviewKit",
            path: "Sources",
            resources: [
                .process("Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "HTMLPreviewKitTests",
            dependencies: ["HTMLPreviewKit"],
            path: "Tests"
        )
    ]
)
