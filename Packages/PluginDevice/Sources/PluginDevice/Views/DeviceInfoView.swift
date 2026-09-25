import Foundation
import LumiUI
import SwiftUI

public struct DeviceInfoView: View {
    @LumiTheme private var theme
    private let viewModels: DevicePluginViewModels

    init(viewModels: DevicePluginViewModels) {
        self.viewModels = viewModels
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    DeviceInfoHeaderView(
                        deviceName: viewModels.deviceData.deviceName,
                        osVersion: viewModels.deviceData.osVersion
                    )

                    DeviceInfoSummaryGrid(
                        deviceData: viewModels.deviceData,
                        cpu: viewModels.cpu,
                        battery: viewModels.battery,
                        gpu: viewModels.gpu
                    )

                    ExternalVolumesView(storage: viewModels.storage)
                    UptimeView(deviceData: viewModels.deviceData)
                }

                Divider()
                    .padding(.horizontal)
                    .foregroundStyle(theme.textTertiary.opacity(0.15))

                VStack(alignment: .leading, spacing: 16) {
                    Label(LumiPluginLocalization.string("Real-time Monitor", bundle: .module), systemImage: "chart.xyaxis.line")
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal)

                    SystemMonitorView(
                        viewModel: viewModels.systemMonitor,
                        gpuViewModel: viewModels.gpu,
                        batteryViewModel: viewModels.battery
                    )
                }
            }
            .padding()
        }
        // 让容器页里的 AppCard 走 subtle 风格，移除默认的 glass shadow / glow，
        // 与 RailView 中其他扁平卡片保持一致。
        .environment(\.appSettingsCardStyleOverride, .subtle)
    }
}

private struct DeviceInfoHeaderView: View {
    @LumiTheme private var theme

    let deviceName: String
    let osVersion: String

    var body: some View {
        AppCard {
            HStack(spacing: 12) {
                Image(systemName: "macbook.and.iphone")
                    .font(.title)
                    .foregroundStyle(theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(deviceName)
                        .font(.appBody)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textPrimary)
                    Text(osVersion)
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                Spacer()
            }
        }
    }
}

private struct DeviceInfoSummaryGrid: View {
    let deviceData: DeviceData
    let cpu: CPUManagerViewModel
    let battery: BatteryManagerViewModel
    let gpu: GPUManagerViewModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            CPUInfoCard(deviceData: deviceData, cpu: cpu)
            MemoryInfoCard(deviceData: deviceData)
            DiskInfoCard(deviceData: deviceData)
            BatteryInfoCard(battery: battery)
            GPUInfoCard(gpu: gpu)
        }
    }
}

private struct CPUInfoCard: View {
    @LumiTheme private var theme
    @ObservedObject private var deviceData: DeviceData
    @ObservedObject private var cpu: CPUManagerViewModel

    init(deviceData: DeviceData, cpu: CPUManagerViewModel) {
        self._deviceData = ObservedObject(wrappedValue: deviceData)
        self._cpu = ObservedObject(wrappedValue: cpu)
    }

    var body: some View {
        DeviceInfoCard(title: LumiPluginLocalization.string("CPU", bundle: .module), icon: "cpu", color: theme.info) {
            VStack(alignment: .leading, spacing: 8) {
                Text(deviceData.processorName.isEmpty ? String(format: LumiPluginLocalization.string("%d cores", bundle: .module), deviceData.coreCount) : deviceData.processorName)
                    .font(.appCaption)
                    .lineLimit(1)
                    .foregroundColor(theme.textSecondary)

                Text("\(Int(deviceData.cpuUsage))%")
                    .font(.appSectionTitle)
                    .foregroundColor(theme.textPrimary)

                ProgressView(value: deviceData.cpuUsage, total: 100)
                    .tint(theme.info)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Text(LumiPluginLocalization.string("User", bundle: .module))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                        Text(String(format: "%.0f%%", cpu.userUsage))
                            .font(.appCaption)
                            .foregroundColor(theme.success)
                    }
                    HStack(spacing: 4) {
                        Text(LumiPluginLocalization.string("System", bundle: .module))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                        Text(String(format: "%.0f%%", cpu.systemUsage))
                            .font(.appCaption)
                            .foregroundColor(theme.warning)
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct MemoryInfoCard: View {
    @LumiTheme private var theme
    @ObservedObject private var deviceData: DeviceData

    init(deviceData: DeviceData) {
        self._deviceData = ObservedObject(wrappedValue: deviceData)
    }

    var body: some View {
        DeviceInfoCard(title: LumiPluginLocalization.string("Memory", bundle: .module), icon: "memorychip", color: theme.success) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(memoryUsedText) / \(memoryTotalText)")
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                ProgressView(value: deviceData.memoryUsage, total: 1.0)
                    .tint(theme.info)
            }
        }
    }

    private var memoryUsedText: String {
        ByteCountFormatter.string(fromByteCount: Int64(deviceData.memoryUsed), countStyle: .memory)
    }

    private var memoryTotalText: String {
        ByteCountFormatter.string(fromByteCount: Int64(deviceData.memoryTotal), countStyle: .memory)
    }
}

private struct DiskInfoCard: View {
    @LumiTheme private var theme
    @ObservedObject private var deviceData: DeviceData

    init(deviceData: DeviceData) {
        self._deviceData = ObservedObject(wrappedValue: deviceData)
    }

    var body: some View {
        DeviceInfoCard(title: LumiPluginLocalization.string("Disk", bundle: .module), icon: "internaldrive", color: theme.warning) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(diskUsedText) \(LumiPluginLocalization.string("used", bundle: .module))")
                    .font(.appCaption)
                    .foregroundColor(theme.textSecondary)

                ProgressView(
                    value: Double(deviceData.diskUsed),
                    total: max(Double(deviceData.diskTotal), 1)
                )
                .tint(theme.info)

                Text(diskTotalText)
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    private var diskUsedText: String {
        ByteCountFormatter.string(fromByteCount: deviceData.diskUsed, countStyle: .file)
    }

    private var diskTotalText: String {
        ByteCountFormatter.string(fromByteCount: deviceData.diskTotal, countStyle: .file)
    }
}

private struct BatteryInfoCard: View {
    @LumiTheme private var theme
    @ObservedObject private var battery: BatteryManagerViewModel

    init(battery: BatteryManagerViewModel) {
        self._battery = ObservedObject(wrappedValue: battery)
    }

    var body: some View {
        DeviceInfoCard(title: LumiPluginLocalization.string("Battery", bundle: .module), icon: batteryIcon, color: batteryLevelColor) {
            VStack(alignment: .leading, spacing: 8) {
                if battery.hasBattery {
                    HStack {
                        Text("\(Int(battery.level * 100))%")
                            .font(.appSectionTitle)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                        if battery.isCharging {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(theme.warning)
                        }
                    }

                    ProgressView(value: battery.level)
                        .tint(batteryLevelColor)

                    HStack(spacing: 12) {
                        if battery.healthPercentage > 0 {
                            Label {
                                Text("\(Int(battery.healthPercentage))%")
                                    .font(.appCaption)
                            } icon: {
                                Image(systemName: "heart.fill")
                                    .font(.appCaption)
                            }
                            .foregroundColor(batteryHealthColor)
                        }
                        if battery.cycleCount > 0 {
                            Label {
                                Text(String(format: LumiPluginLocalization.string("%d cycles", bundle: .module), battery.cycleCount))
                                    .font(.appCaption)
                            } icon: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.appCaption)
                            }
                            .foregroundColor(theme.textSecondary)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "powerplug.fill")
                            .foregroundColor(theme.success)
                        Text(LumiPluginLocalization.string("AC Power", bundle: .module))
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)
                        Spacer()
                    }
                    if battery.adapterWatts > 0 {
                        Text(String(format: LumiPluginLocalization.string("Adapter: %@", bundle: .module), battery.adapterWattsString))
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                    }
                }
            }
        }
    }

    private var batteryIcon: String {
        guard battery.hasBattery else { return "powerplug.fill" }
        let pct = Int(battery.level * 100)
        if battery.isCharging { return "battery.100.bolt" }
        if pct >= 90 { return "battery.100" }
        if pct >= 65 { return "battery.75" }
        if pct >= 40 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    private var batteryLevelColor: Color {
        guard battery.hasBattery else { return theme.success }
        return MetricStatus.batteryLevel(battery.level).color(in: theme)
    }

    private var batteryHealthColor: Color {
        MetricStatus.batteryHealth(battery.healthPercentage).color(in: theme)
    }
}

private struct GPUInfoCard: View {
    @LumiTheme private var theme
    @ObservedObject private var gpu: GPUManagerViewModel

    init(gpu: GPUManagerViewModel) {
        self._gpu = ObservedObject(wrappedValue: gpu)
    }

    var body: some View {
        DeviceInfoCard(title: LumiPluginLocalization.string("GPU", bundle: .module), icon: "cpu", color: theme.info) {
            VStack(alignment: .leading, spacing: 8) {
                Text(gpu.modelName.isEmpty ? LumiPluginLocalization.string("GPU", bundle: .module) : gpu.modelName)
                    .font(.appCaption)
                    .lineLimit(1)
                    .foregroundColor(theme.textSecondary)

                Text(String(format: "%.0f%%", gpu.utilization))
                    .font(.appSectionTitle)
                    .foregroundColor(theme.textPrimary)

                ProgressView(value: gpu.utilization, total: 100)
                    .tint(theme.info)
            }
        }
    }
}

private struct ExternalVolumesView: View {
    @LumiTheme private var theme
    @ObservedObject private var storage: StorageManagerViewModel

    init(storage: StorageManagerViewModel) {
        self._storage = ObservedObject(wrappedValue: storage)
    }

    var body: some View {
        if !storage.externalVolumes.isEmpty {
            VStack(spacing: 12) {
                ForEach(storage.externalVolumes) { volume in
                    AppCard {
                        AppSettingsRow {
                            HStack(spacing: 12) {
                                Image(systemName: "externaldrive")
                                    .font(.appCallout)
                                    .foregroundStyle(theme.warning)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(volume.name)
                                        .font(.appBody)
                                        .foregroundColor(theme.textPrimary)
                                    Text("\(volume.usedString) / \(volume.totalString)")
                                        .font(.appCaption)
                                        .foregroundColor(theme.textSecondary)
                                }

                                Spacer()

                                Text("\(volume.usagePercent)%")
                                    .font(.appBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct UptimeView: View {
    @LumiTheme private var theme
    @ObservedObject private var deviceData: DeviceData

    init(deviceData: DeviceData) {
        self._deviceData = ObservedObject(wrappedValue: deviceData)
    }

    var body: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(theme.textSecondary)
            Text("\(LumiPluginLocalization.string("Uptime", bundle: .module)): \(formatUptime(deviceData.uptime))")
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal)
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

// MARK: - Device Info Card

private struct DeviceInfoCard<Content: View>: View {
    @LumiTheme private var theme

    let title: String
    let icon: String
    let color: Color
    let content: Content

    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        AppCard {
            AppSettingsSection(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.appCaption)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.appCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                }

                content
            }
        }
    }
}
