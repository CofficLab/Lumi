// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LogoSmartLightPlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "LogoSmartLightPlugin",
            targets: ["LogoSmartLightPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
    ],
    targets: [
        .target(
            name: "LogoSmartLightPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Sources"
        )
    ]
)
