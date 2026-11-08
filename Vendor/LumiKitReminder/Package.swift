// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKitReminder",
    platforms: [.macOS("13.1")],
    products: [
        .library(name: "KitReminder", targets: ["KitReminder"])
    ],
    dependencies: [
        .package(path: "../LumiProviders")
    ],
    targets: [
        .target(
            name: "KitReminder",
            dependencies: [
                .product(name: "ProviderStorage", package: "LumiProviders")
            ],
            path: "Sources/KitReminder"
        ),
        .testTarget(
            name: "KitReminderTests",
            dependencies: [
                "KitReminder",
                .product(name: "ProviderStorage", package: "LumiProviders")
            ],
            path: "Tests/KitReminderTests"
        )
    ]
)
