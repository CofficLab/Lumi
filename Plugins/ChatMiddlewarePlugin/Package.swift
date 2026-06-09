// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChatMiddlewarePlugin",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChatMiddlewarePlugin", targets: ["ChatMiddlewarePlugin"])
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/SkillKit"),
        .package(path: "../../Packages/MemoryKit"),
        .package(path: "../../Packages/RAGKit")
    ],
    targets: [
        .target(
            name: "ChatMiddlewarePlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "SkillKit", package: "SkillKit"),
                .product(name: "MemoryKit", package: "MemoryKit"),
                .product(name: "RAGKit", package: "RAGKit")
            ],
            path: "Sources"
        )
    ]
)
