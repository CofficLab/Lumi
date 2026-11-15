// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderLLMContext",
    platforms: [.macOS("14.0"), .iOS(.v17)],
    products: [
        .library(name: "ProviderLLMContext", targets: ["ProviderLLMContext"]),
    ],
    dependencies: [
        .package(url: "https://github.com/lumi-softworks/KitLLM.git", from: "1.0.0"),
        .package(path: "../ProviderMessage"),
    ],
    targets: [
        .target(
            name: "ProviderLLMContext",
            dependencies: [
                .product(name: "KitLLM", package: "KitLLM"),
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
