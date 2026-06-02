import Testing
import LumiCoreKit
import SwiftUI
@testable import PluginDeviceInfo

@MainActor
struct PluginDeviceInfoTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DeviceInfoPlugin.id == "DeviceInfo")
        #expect(DeviceInfoPlugin.navigationId == "device_info")
        #expect(DeviceInfoPlugin.displayName.isEmpty == false)
        #expect(DeviceInfoPlugin.description.isEmpty == false)
        #expect(DeviceInfoPlugin.iconName == "macbook.and.iphone")
        #expect(DeviceInfoPlugin.isConfigurable == false)
        #expect(DeviceInfoPlugin.category == .general)
        #expect(DeviceInfoPlugin.order == 10)
        #expect(DeviceInfoPlugin.policy == .disabled)
        #expect(DeviceInfoPlugin.shared.instanceLabel == DeviceInfoPlugin.id)
    }

    @Test
    func uiContributionsAreProvided() {
        let item = DeviceInfoPlugin.shared.addViewContainer()
        #expect(item?.id == DeviceInfoPlugin.id)
        #expect(item?.title == DeviceInfoPlugin.displayName)
        #expect(item?.icon == DeviceInfoPlugin.iconName)
        #expect(DeviceInfoPlugin.shared.addMenuBarContentView() != nil)
        #expect(DeviceInfoPlugin.shared.addMenuBarPopupViews().count == 2)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDeviceInfoLocalization.bundle.url(forResource: "DeviceInfo", withExtension: "xcstrings") != nil)
        #expect(PluginDeviceInfoLocalization.string("Device Info").isEmpty == false)
    }

    @Test
    func menuBarMetricsUseVisiblePrecisionForDeduplication() {
        let first = DeviceInfoMenuBarMetrics(
            cpu: DeviceInfoMenuBarCPUMetrics(usagePercent: 17, perCoreUsagePercent: [3, 42]),
            memory: DeviceInfoMenuBarMemoryMetrics(usagePercent: 61, usedMemory: "19 GB", totalMemory: "32 GB")
        )
        let equivalent = DeviceInfoMenuBarMetrics(
            cpu: DeviceInfoMenuBarCPUMetrics(usagePercent: 17, perCoreUsagePercent: [3, 42]),
            memory: DeviceInfoMenuBarMemoryMetrics(usagePercent: 61, usedMemory: "19 GB", totalMemory: "32 GB")
        )
        let changed = DeviceInfoMenuBarMetrics(
            cpu: DeviceInfoMenuBarCPUMetrics(usagePercent: 18, perCoreUsagePercent: [3, 42]),
            memory: DeviceInfoMenuBarMemoryMetrics(usagePercent: 61, usedMemory: "19 GB", totalMemory: "32 GB")
        )

        #expect(first == equivalent)
        #expect(first != changed)
    }

    @Test
    func menuBarSnapshotUsesCachedImagesAndReadableHelp() {
        let metrics = DeviceInfoMenuBarMetrics(
            cpu: DeviceInfoMenuBarCPUMetrics(usagePercent: 12, perCoreUsagePercent: [10, 14]),
            memory: DeviceInfoMenuBarMemoryMetrics(usagePercent: 64, usedMemory: "20 GB", totalMemory: "32 GB")
        )
        let snapshot = DeviceInfoMenuBarSnapshot(metrics: metrics)

        #expect(snapshot.cpuImage.size.width > 0)
        #expect(snapshot.memoryImage.size.width > 0)
        #expect(snapshot.cpuHelpText.contains("12"))
        #expect(snapshot.memoryHelpText.contains("64"))
    }

    @Test
    func deviceDataUsesInjectedCPUUsageProvider() {
        let counter = DeviceDataMonitorCounter()
        let data = DeviceData(
            cpuUsageProvider: { 73.5 },
            cpuMonitoringStarter: { counter.starts += 1 },
            cpuMonitoringStopper: { counter.stops += 1 }
        )

        #expect(data.cpuUsage == 73.5)
        #expect(counter.starts == 1)

        data.startMonitoring()
        #expect(counter.starts == 1)

        data.stopMonitoring()
        data.stopMonitoring()
        #expect(counter.stops == 1)
    }

    @Test
    func historyGraphsIgnoreInvalidScales() {
        let rect = CGRect(x: 0, y: 0, width: 120, height: 60)

        let cpuLine = CPUGraphLine(data: [0, 0], maxValue: 0).path(in: rect)
        let cpuArea = CPUGraphArea(data: [0, 0], maxValue: .infinity).path(in: rect)
        let memoryLine = MemoryGraphLine(data: [0, 0], maxValue: 0).path(in: rect)
        let memoryArea = MemoryGraphArea(data: [0, 0], maxValue: .nan).path(in: rect)

        #expect(cpuLine.isEmpty)
        #expect(cpuArea.isEmpty)
        #expect(memoryLine.isEmpty)
        #expect(memoryArea.isEmpty)
    }
}

@MainActor
private final class DeviceDataMonitorCounter {
    var starts = 0
    var stops = 0
}
