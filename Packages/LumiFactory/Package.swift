// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LumiFactory",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LumiFactory", targets: ["LumiFactory"]),
    ],
    dependencies: [
        .package(path: "../LumiCoreKit"),
        .package(path: "../LumiKernel"),
        .package(path: "../LumiUI"),
        .package(path: "../LocalizationKit"),
        .package(path: "../SuperLogKit"),
        .package(path: "../EditorService"),
        .package(path: "../../Plugins/EditorPanelPlugin"),
        .package(path: "../../Plugins/StoragePlugin"),
        .package(path: "../../Plugins/ProjectsPlugin"),
        .package(path: "../../Plugins/AgentToolPlugin"),
        .package(path: "../../Plugins/LayoutKernelPlugin"),
        .package(path: "../../Plugins/EditorKernelPlugin"),
        .package(path: "../../Plugins/ChatKernelPlugin"),
        .package(path: "../../Plugins/DeviceInfoKernelPlugin"),
        .package(path: "../../Plugins/ClipboardManagerPlugin"),
    ],
    targets: [
        .target(
            name: "LumiFactory",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiKernel", package: "LumiKernel"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "LocalizationKit", package: "LocalizationKit"),
                .product(name: "SuperLogKit", package: "SuperLogKit"),
                .product(name: "EditorPanelPlugin", package: "EditorPanelPlugin"),
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "StoragePlugin", package: "StoragePlugin"),
                .product(name: "ProjectsPlugin", package: "ProjectsPlugin"),
                .product(name: "AgentToolPlugin", package: "AgentToolPlugin"),
                .product(name: "LayoutKernelPlugin", package: "LayoutKernelPlugin"),
                .product(name: "EditorKernelPlugin", package: "EditorKernelPlugin"),
                .product(name: "ChatKernelPlugin", package: "ChatKernelPlugin"),
                .product(name: "DeviceInfoKernelPlugin", package: "DeviceInfoKernelPlugin"),
                .product(name: "ClipboardManagerPlugin", package: "ClipboardManagerPlugin"),
            ]
        ),
    ]
)