// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppStorePromoKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppStorePromoKit", targets: ["AppStorePromoKit"]),
    ],
    dependencies: [
        .package(path: "../HTMLPreviewKit"),
    ],
    targets: [
        .target(
            name: "AppStorePromoKit",
            dependencies: [
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
            ]
        ),
        .testTarget(
            name: "AppStorePromoKitTests",
            dependencies: ["AppStorePromoKit"]
        ),
    ]
)
