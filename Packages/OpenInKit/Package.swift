// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenInKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "OpenInKit",
            targets: ["OpenInKit"]
        )
    ],
    dependencies: [
        .package(path: "../LocalizationKit"),
    ],

    targets: [
        .target(
            name: "OpenInKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "OpenInKitTests",
            dependencies: ["OpenInKit"],
            path: "Tests"
        )
    ]
)
