// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EditorProviderPlugin",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EditorProviderPlugin", targets: ["EditorProviderPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/EditorSource"),
        .package(path: "../../Packages/EditorTextView"),
        .package(path: "../../Packages/EditorLanguageRuntime"),
    ],
    targets: [
        .target(
            name: "EditorProviderPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "EditorSource", package: "EditorSource"),
                .product(name: "EditorTextView", package: "EditorTextView"),
                .product(name: "EditorLanguageRuntime", package: "EditorLanguageRuntime"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: ".",
            exclude: ["Tests"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(
            name: "EditorProviderPluginTests",
            dependencies: [
                "EditorProviderPlugin",
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiUI", package: "LumiUI"),
            ]
        ),
    ]
)
