// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EditorSwiftPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "EditorSwiftPlugin",
            targets: ["EditorSwiftPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/KernelLumi"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/LocalizationKit"),
        .package(path: "../../Packages/ShellKit"),
        // Official tree-sitter/tree-sitter-swift has no Package.swift; use SPM-compatible fork.
        .package(url: "https://github.com/alex-pinkus/tree-sitter-swift.git", branch: "with-generated-files"),
    ],
    targets: [
        .target(
            name: "EditorSwiftPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "ShellKit", package: "ShellKit"),
                .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
            ],
            path: "Sources",
            exclude: [
                "Commands",
                "Contributors",
                "Models",
                "Services",
                "Tools",
                "ViewModels",
                "Views",
                "EditorSwiftKeywordHoverContributor.swift",
                "SwiftPrimitiveTypeCompletionContributor.swift",
                "SwiftSelectionCodeActionContributor.swift",
            ],
            resources: [
                .process("../Resources/Localizable.xcstrings"),
                .copy("Resources"),
            ]
        ),
        .testTarget(
            name: "EditorSwiftPluginTests",
            dependencies: [
                "EditorSwiftPlugin",
                .product(name: "KernelLumi", package: "KernelLumi"),
            ],
            path: "Tests",
            exclude: [
                "EditorSwiftBuildServerStoreTests.swift",
                "EditorSwiftHostEnvironmentConfigurationTests.swift",
                "EditorSwiftIntegrationTests.swift",
                "EditorSwiftStorageTests.swift",
                "GenerateXcodeProjectToolParserTests.swift",
                "SwiftAgentToolsTests.swift",
                "SwiftBuildRunTests.swift",
                "SwiftContributorsTests.swift",
                "XcodeProjectContextStatusMapperTests.swift",
                "XcodeProjectStatusBarContrastTests.swift",
                "XcodeProjectStatusBarViewModelTests.swift",
                "XcodeProjectStatusPresentationTests.swift",
            ]
        )
    ]
)
