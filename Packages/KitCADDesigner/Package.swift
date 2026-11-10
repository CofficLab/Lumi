// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitCADDesigner",
    defaultLocalization: "en",
    platforms: [.macOS("13.1")],
    products: [
        .library(name: "KitCADDesigner", targets: ["KitCADDesigner"]),
    ],
    dependencies: [
        .package(path: "../../Vendor/LumiLocalization"),
        .package(path: "../../Vendor/LumiUI"),
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
