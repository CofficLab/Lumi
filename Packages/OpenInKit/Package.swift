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
        .package(path: "../LumiLocalizationKit"),
    ],

    targets: [
        .target(
            name: "OpenInKit",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalizationKit"),
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
