// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitCADDesigner",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KitCADDesigner", targets: ["KitCADDesigner"]),
    ],
    dependencies: [
        .package(path: "../KitLocalization"),
        .package(url: "https://github.com/CofficLab/LumiUI.git", from: "1.7.0"),
    ],
    targets: [
        .target(
            name: "KitCADDesigner",
            dependencies: [
                .product(name: "KitLocalization", package: "KitLocalization"),
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
