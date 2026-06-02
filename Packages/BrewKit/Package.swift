// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BrewKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BrewKit", targets: ["BrewKit"])],
    dependencies: [
        .package(path: "../ShellKit")
    ],
    targets: [
        .target(
            name: "BrewKit",
            dependencies: [
                .product(name: "ShellKit", package: "ShellKit")
            ],
            path: "Sources/BrewKit"
        ),
        .testTarget(name: "BrewKitTests", dependencies: ["BrewKit"], path: "Tests")
    ]
)
