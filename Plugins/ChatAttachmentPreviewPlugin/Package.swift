// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatAttachmentPreviewPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ChatAttachmentPreviewPlugin",
            targets: ["ChatAttachmentPreviewPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "ChatAttachmentPreviewPlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: "Sources"
        ),
    ]
)