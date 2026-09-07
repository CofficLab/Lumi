// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderDiagnostics",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderDiagnostics",
            targets: ["ProviderDiagnostics"]
        ),
    ],
    targets: [
        .target(
            name: "ProviderDiagnostics",
            path: "Sources/ProviderDiagnostics"
        ),
        .testTarget(
            name: "ProviderDiagnosticsTests",
            dependencies: ["ProviderDiagnostics"],
            path: "Tests/ProviderDiagnosticsTests"
        )
    ]
)
