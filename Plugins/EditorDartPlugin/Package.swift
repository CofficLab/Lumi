// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorDartPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorDartPlugin", targets: ["EditorDartPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "Vendor/TreeSitterDart"),
    ],
    targets: [
        .target(
            name: "EditorDartPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterDart", package: "TreeSitterDart"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorDartPluginTests", dependencies: ["EditorDartPlugin"], path: "Tests"),
    ]
)
