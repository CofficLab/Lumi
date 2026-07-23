// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatFileAttachmentPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatFileAttachmentPlugin",
            targets: ["ChatFileAttachmentPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ChatFileAttachmentPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
    ]
)
