// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShellKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShellKit", targets: ["ShellKit"]),
    ],
    dependencies: [
        .package(path: "../LocalizationKit"),
    ],

    targets: [
        .target(
            name: "ShellKit",
            dependencies: [
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(name: "ShellKitTests", dependencies: ["ShellKit"],
            path: "Tests"),
    ]
)