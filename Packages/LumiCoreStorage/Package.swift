// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiCoreStorage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LumiCoreStorage",
            targets: ["LumiCoreStorage"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "LumiCoreStorage",
            path: "Sources"
        ),
    ]
)