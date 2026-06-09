// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LLMProviderZhipuPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LLMProviderZhipuPlugin",
            targets: ["LLMProviderZhipuPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/HttpKit"),
        .package(path: "../../Packages/LLMKit"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
    ],
    targets: [
        .target(
            name: "LLMProviderZhipuPlugin",
            dependencies: [
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md",
                "Sources/Services/MessageTransformer.swift",
                "Sources/Services/RequestBuilder.swift",
                "Sources/Services/ResponseParser.swift",
                "Sources/Services/StreamParser.swift",
                "Sources/Services/ZhipuChatTransport.swift",
                "Sources/Services/ZhipuRequestDebugLog.swift",
                "Sources/ZhipuProvider+ErrorMessage.swift",
            ],
            sources: [
                "Sources/ZhipuPlugin.swift",
                "Sources/ZhipuProvider.swift",
                "Sources/ZhipuRenderKind.swift",
                "Sources/Model",
                "Sources/Renderers",
                "Sources/Services/QuotaService.swift",
                "Sources/Views/ApiKeyMissingView.swift",
                "Sources/Views/ErrorMessageLayout.swift",
                "Sources/Views/HttpErrorView.swift",
                "Sources/Views/ProviderBadge.swift",
                "Sources/Views/QuotaDetailView.swift",
                "Sources/Views/StatusBarView.swift",
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "LLMProviderZhipuPluginTests",
            dependencies: [
                "LLMProviderZhipuPlugin",
                .product(name: "HttpKit", package: "HttpKit"),
                .product(name: "LLMKit", package: "LLMKit"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
            ],
            path: "Tests",
            exclude: [
                "ZhipuChatTransportTests.swift",
            ]
        )
    ]
)
