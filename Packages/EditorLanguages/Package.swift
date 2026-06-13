// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let hasCodeLanguagesContainer = FileManager.default.fileExists(
    atPath: packageRoot.appendingPathComponent("CodeLanguagesContainer.xcframework").path
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
    name: "EditorLanguages",
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "EditorLanguages",
            targets: ["EditorLanguages"]
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
            name: "EditorLanguages",
            dependencies: [codeLanguagesContainerDependency, "SwiftTreeSitter"],
            path: "Sources",
            exclude: ["CodeLanguages_Container"],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [.linkedLibrary("c++")]
        ),
        codeLanguagesContainerTarget,
        .testTarget(
            name: "EditorLanguagesTests",
            dependencies: ["EditorLanguages"],
            path: "Tests"
        ),
    ]
)
