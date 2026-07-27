// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TerminalCoreKit",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "TerminalCoreKit", targets: ["TerminalCoreKit"])],
    dependencies: [
        .package(path: "../LocalizationKit"),
        .package(url: "https://github.com/migueldeicaza/SwiftTerm", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "TerminalCoreKit",
            dependencies: ["SwiftTerm",
                .product(name: "LocalizationKit", package: "LocalizationKit"),
            ],
            path: "Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "TerminalCoreKitTests",
            dependencies: ["TerminalCoreKit"],
            path: "Tests"
        )
    ]
)