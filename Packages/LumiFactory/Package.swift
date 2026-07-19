// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumiFactory",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiFactory", targets: ["LumiFactory"]),
    ],
    dependencies: [
        .package(path: "../LumiKernel"),
        .package(path: "../SuperLogKit"),
        .package(path: "../../Plugins/StoragePlugin"),
        .package(path: "../../Plugins/ProjectsPlugin"),
        .package(path: "../../Plugins/AgentToolPlugin"),
        .package(path: "../../Plugins/LayoutKernelPlugin"),
        .package(path: "../../Plugins/EditorKernelPlugin"),
        .package(path: "../../Plugins/ChatKernelPlugin"),
        .package(path: "../../Plugins/DeviceInfoKernelPlugin"),
    ],
    targets: [
        .target(
            name: "LumiFactory",
            dependencies: [
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "StoragePlugin", package: "StoragePlugin"),
                .product(name: "ProjectsPlugin", package: "ProjectsPlugin"),
                .product(name: "AgentToolPlugin", package: "AgentToolPlugin"),
                .product(name: "LayoutKernelPlugin", package: "LayoutKernelPlugin"),
                .product(name: "EditorKernelPlugin", package: "EditorKernelPlugin"),
                .product(name: "ChatKernelPlugin", package: "ChatKernelPlugin"),
                .product(name: "DeviceInfoKernelPlugin", package: "DeviceInfoKernelPlugin"),
            ]
        ),
    ]
)