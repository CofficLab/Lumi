// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EditorKernelPlugin",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EditorKernelPlugin", targets: ["EditorKernelPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "EditorKernelPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: ".",
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
    ]
)
