// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppStorePromoDesignerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppStorePromoDesignerPlugin", targets: ["AppStorePromoDesignerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/AppStorePromoKit"),
        .package(path: "../../Packages/HTMLPreviewKit"),
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "AppStorePromoDesignerPlugin",
            dependencies: [
                .product(name: "AppStorePromoKit", package: "AppStorePromoKit"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources/AppStorePromoDesignerPlugin",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "AppStorePromoDesignerPluginTests",
            dependencies: [
                "AppStorePromoDesignerPlugin",
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Tests/AppStorePromoDesignerPluginTests"
        ),
    ]
)
