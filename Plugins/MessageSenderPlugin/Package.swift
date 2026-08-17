// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MessageSenderPlugin",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MessageSenderPlugin", targets: ["MessageSenderPlugin"]),
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ProviderStorage"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "MessageSenderPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "ProviderStorage", package: "ProviderStorage"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources"
        ,
            resources: [.process("../Resources/Localizable.xcstrings")]),
    ]
)
