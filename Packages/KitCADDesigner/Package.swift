// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitCADDesigner",
    defaultLocalization: "en",
    platforms: [.macOS("14.0")],
    products: [
        .library(name: "KitCADDesigner", targets: ["KitCADDesigner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/LumiLocalization.git", from: "1.0.1"),
        .package(url: "https://github.com/lumi-softworks/LumiUI.git", from: "1.13.0"),
    ],
    targets: [
        .target(
            name: "KitCADDesigner",
            dependencies: [
                .product(name: "LumiLocalizationKit", package: "LumiLocalization"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            resources: [
                .process("../../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "KitCADDesignerTests",
            dependencies: ["KitCADDesigner"],
            path: "Tests/KitCADDesignerTests"
        ),
    ]
)
