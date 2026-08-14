// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ResumeDesignerPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ResumeDesignerPlugin", targets: ["ResumeDesignerPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/ResumeKit"),
        .package(path: "../../Packages/HTMLPreviewKit"),
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
    ],
    targets: [
        .target(
            name: "ResumeDesignerPlugin",
            dependencies: [
                .product(name: "ResumeKit", package: "ResumeKit"),
                .product(name: "HTMLPreviewKit", package: "HTMLPreviewKit"),
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources/ResumeDesignerPlugin",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "ResumeDesignerPluginTests",
            dependencies: [
                "ResumeDesignerPlugin",
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "ResumeKit", package: "ResumeKit"),
            ],
            path: "Tests/ResumeDesignerPluginTests"
        ),
    ]
)
