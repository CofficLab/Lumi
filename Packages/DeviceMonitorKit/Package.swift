// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceMonitorKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DeviceMonitorKit",
            targets: ["DeviceMonitorKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/CofficLab/MagicKit", from: "1.5.23"),
    ],
    targets: [
        .target(
            name: "DeviceMonitorKit",
            dependencies: [
                .product(name: "MagicKit", package: "MagicKit"),
            ],
            path: "Sources/DeviceMonitorKit"
        ),
        .testTarget(
            name: "DeviceMonitorKitTests",
            dependencies: ["DeviceMonitorKit"],
            path: "Tests/DeviceMonitorKitTests"
        )
    ]
)
