// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProviderWebServer",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.1"),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "ProviderWebServer",
            targets: ["ProviderWebServer"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "ProviderWebServer",
            path: "Sources/ProviderWebServer",
            sources: [
                "DefaultWebServerProviding.swift",
                "HTTPMethod.swift",
                "WebAPIError.swift",
                "WebAuthPolicy.swift",
                "WebCORSPolicy.swift",
                "WebPagination.swift",
                "WebRequestActivity.swift",
                "WebRoute.swift",
                "WebRouteBuilder.swift",
                "WebServerExtendedProviding.swift",
                "WebServerProviding.swift",
            ]
        ),
        .testTarget(
            name: "ProviderWebServerTests",
            dependencies: ["ProviderWebServer"]
        )
    ]
)
