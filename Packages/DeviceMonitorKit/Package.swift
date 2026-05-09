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
    dependencies: [],
    targets: [
        .target(
            name: "DeviceMonitorKit",
            path: "Sources/DeviceMonitorKit"
        ),
        .testTarget(
            name: "DeviceMonitorKitTests",
            dependencies: ["DeviceMonitorKit"],
            path: "Tests/DeviceMonitorKitTests"
        )
    ]
)
