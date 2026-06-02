// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SkillKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SkillKit",
            targets: ["SkillKit"]
        )
    ],
    targets: [
        .target(
            name: "SkillKit"
            path: "Sources"
        ),
        .testTarget(
            name: "SkillKitTests",
            dependencies: ["SkillKit"],
            path: "Tests"
        )
    ]
)
