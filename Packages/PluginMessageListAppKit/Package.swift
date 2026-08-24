// swift-tools-version: 6.0
import PackageDescription

// MARK: - Notes on declared dependencies
//
// `KernelLumi` and `LocalizationKit` are used today by the plugin entry
// point (LumiPlugin conformance, LumiPluginLocalization helper).
//
// The remaining four packages are forward-looking and are intentionally
// pulled in now so the target can `import` them as soon as later tasks
// land without having to touch Package.swift each time:
//
//   - `LumiUI`                  — Task 4+ (when SwiftUI hosting is used
//                                  only inside the AppKit bridge, never
//                                  inside message renderers).
//   - `SuperLogKit`             — light logging helper reserved for
//                                  Task 15 diagnostics.
//   - `MarkdownKit` (Core only)  — Task 8 (native block parsing). The
//                                  SwiftUI `MarkdownKit` product is
//                                  intentionally NOT consumed.
//   - `beautiful-mermaid-swift` — Task 10 (native Mermaid rendering).
//
// Do not remove or rename these without first updating the plan; the
// `SourceBoundaryTests` regex also asserts that the SwiftUI
// `MarkdownKit` product is never pulled in directly.

let package = Package(
    name: "PluginMessageListAppKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MessageListAppKitPlugin", targets: ["MessageListAppKitPlugin"]),
    ],
    dependencies: [
        // Core kit packages (sibling under Packages/).
        .package(path: "../KernelLumi"),
        .package(path: "../LocalizationKit"),
        .package(path: "../LumiUI"),
        .package(path: "../SuperLogKit"),
        // Markdown block parsing only — the SwiftUI `MarkdownKit` product is
        // intentionally NOT used (per the implementation plan).
        .package(path: "../MarkdownKit"),
        // Mermaid renderer is consumed directly so this target can import the
        // `BeautifulMermaid` product without pulling in SwiftUI MarkdownKit.
        .package(url: "https://github.com/lukilabs/beautiful-mermaid-swift", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MessageListAppKitPlugin",
            dependencies: [
                .product(name: "KernelLumi", package: "KernelLumi"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "MarkdownKitCore", package: "MarkdownKit"),
                .product(name: "BeautifulMermaid", package: "beautiful-mermaid-swift"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources/Localizable.xcstrings"),
            ]
        ),
        .testTarget(
            name: "MessageListAppKitPluginTests",
            dependencies: ["MessageListAppKitPlugin"],
            path: "Tests",
            resources: [
                .process("Fixtures"),
            ]
        ),
    ]
)
