// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorOCamlPlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "EditorOCamlPlugin", targets: ["EditorOCamlPlugin"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        // Vendored: upstream examples/ git submodules break SPM resolution on slow networks.
        .package(path: "Vendor/TreeSitterOCaml"),
    ],
    targets: [
        .target(
            name: "EditorOCamlPlugin",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "TreeSitterOCaml", package: "TreeSitterOCaml"),
            ],
            path: "Sources",
            resources: [.copy("Resources"), .process("../Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "EditorOCamlPluginTests", dependencies: ["EditorOCamlPlugin"], path: "Tests"),
    ]
)
