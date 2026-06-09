// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DeviceInfoPlugin",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DeviceInfoPlugin",
            targets: ["DeviceInfoPlugin"]
        )
    ],
    dependencies: [
        .package(path: "../../Packages/LumiCoreKit"),
        .package(path: "../../Packages/LumiUI"),
        .package(path: "../../Packages/SuperLogKit")
    ],
    targets: [
        .target(
            name: "DeviceInfoPlugin",
            dependencies: [
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "LumiUI", package: "LumiUI"),
                .product(name: "SuperLogKit", package: "SuperLogKit")
            ],
            path: ".",
            exclude: [
                "Tests",
                "README.md"
            ],
            sources: [
                "Sources/DeviceInfoPlugin.swift",
                "Sources/DeviceData.swift",
                "Sources/Models/CPUModels.swift",
                "Sources/Models/MemoryModels.swift",
                "Sources/Models/MonitorModels.swift",
                "Sources/Services/CPUHistoryService.swift",
                "Sources/Services/CPUService.swift",
                "Sources/Services/MemoryHistoryService.swift",
                "Sources/Services/MemoryService.swift",
                "Sources/Services/ProcessService.swift",
                "Sources/Services/SystemMonitorService.swift",
                "Sources/ViewModels/SystemMonitorViewModel.swift",
                "Sources/ViewModels/CPUManagerViewModel.swift",
                "Sources/ViewModels/MemoryManagerViewModel.swift",
                "Sources/Views/CPUHistoryDetailView.swift",
                "Sources/Views/CPUHistoryGraphView.swift",
                "Sources/Views/CPUMenuBarChartRenderer.swift",
                "Sources/Views/DeviceInfoView.swift",
                "Sources/Views/DeviceInfoMenuBarContentView.swift",
                "Sources/Views/DeviceInfoMenuBarPopupView.swift",
                "Sources/Views/MemoryHistoryDetailView.swift",
                "Sources/Views/MemoryHistoryGraphView.swift",
                "Sources/Views/MemoryMenuBarChartRenderer.swift",
                "Sources/Views/MemoryMenuBarPopupView.swift",
                "Sources/Views/SystemMonitorView.swift",
                "Sources/Views/TopProcessesView.swift",
                "Sources/Views/WaveformView.swift"
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DeviceInfoPluginTests",
            dependencies: ["DeviceInfoPlugin"],
            path: "Tests"
        )
    ]
)
