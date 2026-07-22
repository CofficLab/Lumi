// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKernel",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiKernel",
            targets: ["LumiKernel"]
        ),
    ],
    dependencies: [
        .package(path: "../LumiUI"),
        .package(path: "../LumiCoreLayout"),
        .package(path: "../LumiCoreMenuBar"),
        .package(path: "../LumiCoreOverlay"),
        .package(path: "../LumiCorePanelChrome"),
        .package(path: "../LumiCoreProject"),
        .package(path: "../LumiCoreStorage"),
    ],
    targets: [
        .target(
            name: "LumiKernel",
            dependencies: [
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LumiCoreLayout", package: "LumiCoreLayout"),
                .product(name: "LumiCoreMenuBar", package: "LumiCoreMenuBar"),
                .product(name: "LumiCoreOverlay", package: "LumiCoreOverlay"),
                .product(name: "LumiCorePanelChrome", package: "LumiCorePanelChrome"),
                .product(name: "LumiCoreProject", package: "LumiCoreProject"),
                .product(name: "LumiCoreStorage", package: "LumiCoreStorage"),
            ],
            path: "Sources/LumiKernel",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LumiKernelTests",
            dependencies: ["LumiKernel"]
        )
    ]
)
