// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryCoreMobile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FactoryCoreMobile", targets: ["FactoryCoreMobile"]),
    ],
    dependencies: [
        .package(path: "../KernelHosting"),
        .package(path: "../KernelLumi"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
    ],
    targets: [
        .target(
            name: "FactoryCoreMobile",
            dependencies: [
                .product(name: "KernelHosting", package: "KernelHosting"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ]
        )
    ]
)
