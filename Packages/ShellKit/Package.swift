// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShellKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ShellKit", targets: ["ShellKit"]),
    ],
    targets: [
        .target(
            name: "ShellKit",
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(name: "ShellKitTests", dependencies: ["ShellKit"],
            path: "Tests"),
    ]
)