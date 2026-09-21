// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KitAppStorePromo",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "KitAppStorePromo", targets: ["KitAppStorePromo"]),
    ],
    dependencies: [],
    targets: [
        .target(name: "KitAppStorePromo"),
        .testTarget(
            name: "KitAppStorePromoTests",
            dependencies: ["KitAppStorePromo"],
            resources: [.copy("Fixtures/FeatureSVGPrintRegression.html")]
        ),
    ]
)
