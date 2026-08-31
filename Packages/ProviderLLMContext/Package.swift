// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLLMContext",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ProviderLLMContext", targets: ["ProviderLLMContext"]),
    ],
    dependencies: [
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLLMContext",
            dependencies: [
                .product(name: "ProviderMessage", package: "ProviderMessage"),
            ],
            path: "Sources/ProviderLLMContext"
        ),
        .testTarget(
            name: "ProviderLLMContextTests",
            dependencies: ["ProviderLLMContext"],
            path: "Tests/ProviderLLMContextTests"
        ),
    ]
)
