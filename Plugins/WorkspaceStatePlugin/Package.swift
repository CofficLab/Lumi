// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WorkspaceStatePlugin",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "WorkspaceStatePlugin",
            targets: ["WorkspaceStatePlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKernel"),
    ],
    targets: [
        .target(
            name: "WorkspaceStatePlugin",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
            ],
            path: "Sources/WorkspaceStatePlugin"
        )
    ]
)