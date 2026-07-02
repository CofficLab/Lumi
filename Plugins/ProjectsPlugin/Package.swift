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
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI")
    ],
    targets: [
        .target(
            name: "ProjectsPlugin",
            dependencies: [
                "LumiCoreKit",
                "LumiUI"
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings")
            ]
        ),
        .testTarget(
            name: "ProjectsPluginTests",
            dependencies: ["ProjectsPlugin"]
        )
    ]
)
