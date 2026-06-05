// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let hasCodeLanguagesContainer = FileManager.default.fileExists(
    atPath: "CodeLanguagesContainer.xcframework"
)

let codeLanguagesContainerDependency: Target.Dependency = hasCodeLanguagesContainer
    ? "CodeLanguagesContainer"
    : "CodeLanguages_Container"

let codeLanguagesContainerTarget: Target = hasCodeLanguagesContainer
    ? .binaryTarget(
        name: "CodeLanguagesContainer",
        path: "CodeLanguagesContainer.xcframework"
    )
    : .target(
        name: "CodeLanguages_Container",
        path: "Sources/CodeLanguages_Container",
        publicHeadersPath: "include"
    )

let package = Package(
    name: "CodeEditLanguages",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "CodeEditLanguages",
            targets: ["CodeEditLanguages"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/ChimeHQ/SwiftTreeSitter.git",
            from: "0.9.0"
        ),
    ],
    targets: [
        .target(
            name: "CodeEditLanguages",
            dependencies: [codeLanguagesContainerDependency, "SwiftTreeSitter"],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/CodeLanguages_Container",
                "CodeLanguages-Container",
                "DerivedData",
                "build_framework.sh",
            ],
            sources: ["Sources"],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),
        codeLanguagesContainerTarget,
        .testTarget(
            name: "CodeEditLanguagesTests",
            dependencies: ["CodeEditLanguages"],
            path: "Tests"
        ),
    ]
)
