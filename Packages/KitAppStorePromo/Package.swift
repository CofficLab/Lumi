// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitAppStorePromo",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitAppStorePromo", targets: ["KitAppStorePromo"]),
    ],
    dependencies: [
        .package(path: "../KitHTMLPreview"),
    ],
    targets: [
        .target(
            name: "KitAppStorePromo",
            dependencies: [
                .product(name: "KitHTMLPreview", package: "KitHTMLPreview"),
            ]
        ),
        .testTarget(
            name: "KitAppStorePromoTests",
            dependencies: ["KitAppStorePromo"]
        ),
    ]
)
