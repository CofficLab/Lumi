// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectsPlugin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ProjectsPlugin",
            targets: ["ProjectsPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Plugins/ChatMiddlewarePlugin")
    ],
    targets: [
        .target(
            name: "ProjectsPlugin",
            dependencies: [
                "LumiCoreKit",
                "LumiUI",
                .product(name: "ChatMiddlewarePlugin", package: "ChatMiddlewarePlugin")
            ]
        ),
        .testTarget(
            name: "ProjectsPluginTests",
            dependencies: ["ProjectsPlugin"]
        )
    ]
)
