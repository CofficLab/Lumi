// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProjectsPlugin",
    defaultLocalization: "en",
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
        .package(path: "../../Packages/AgentToolKit"),
        .package(path: "../../Packages/GitBranchMonitorKit"),
        .package(url: "https://github.com/nookery/Libgit2swift", .branch("main")),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit"),
    ],
    targets: [
        .target(
            name: "ProjectsPlugin",
            dependencies: [
                .product(name: "AgentToolKit", package: "AgentToolKit"),
                .product(name: "GitBranchMonitorKit", package: "GitBranchMonitorKit"),
                .product(name: "LibGit2Swift", package: "Libgit2swift"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
            ],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ProjectsPluginTests",
            dependencies: ["ProjectsPlugin"],
            path: "Tests"
        )
    ]
)
