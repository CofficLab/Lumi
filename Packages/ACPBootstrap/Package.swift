// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ACPBootstrap",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../FactoryLumiACP"),
    ],
    targets: [
        .executableTarget(
            name: "ACPBootstrap",
            dependencies: [
                .product(name: "FactoryLumiACP", package: "FactoryLumiACP"),
            ],
            path: "Sources/ACPBootstrap"
        ),
    ]
)
