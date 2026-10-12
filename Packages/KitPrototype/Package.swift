// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitPrototype",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitPrototype", targets: ["KitPrototype"]),
    ],
    dependencies: [
        .package(path: "../KitHTMLPreview"),
    ],
    targets: [
        .target(
            name: "KitPrototype",
            dependencies: [
                .product(name: "KitHTMLPreview", package: "KitHTMLPreview"),
            ]
        ),
        .testTarget(
            name: "KitPrototypeTests",
            dependencies: ["KitPrototype"]
        ),
    ]
)
