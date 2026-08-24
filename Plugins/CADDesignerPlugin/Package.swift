// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CADDesignerPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CADDesignerPlugin",
            targets: ["CADDesignerPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "CADDesignerPlugin",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "CADDesignerPluginTests",
            dependencies: ["CADDesignerPlugin"],
            path: "Tests"
        )
    ]
)
