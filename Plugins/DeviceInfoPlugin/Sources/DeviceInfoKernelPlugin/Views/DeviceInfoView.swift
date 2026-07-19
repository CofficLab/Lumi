import Foundation
import LumiUI
import SwiftUI

public struct DeviceInfoView: View {
    @LumiTheme private var theme
    @StateObject private var data = DeviceData()
    @ObservedObject private var gpuService = GPUService.shared
    @ObservedObject private var batteryService = BatteryService.shared
    @ObservedObject private var storageService = StorageService.shared
    @ObservedObject private var cpuService = CPUService.shared

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    AppCard {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(theme.primary.opacity(0.1))
                                    .frame(width: 60, height: 60)

                                Image(systemName: "macbook.and.iphone")
                                    .font(.largeTitle)
                                    .foregroundStyle(theme.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(data.deviceName)
                                    .font(.title.weight(.semibold))
                                    .foregroundColor(theme.textPrimary)
                                Text(data.osVersion)
                                    .font(.body)
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DeviceInfoCard(title: LumiPluginLocalization.string("CPU", bundle: .module), icon: "cpu", color: theme.info) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(data.processorName.isEmpty ? String(format: LumiPluginLocalization.string("%d cores", bundle: .module), data.coreCount) : data.processorName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(theme.textSecondary)

                                HStack(alignment: .bottom) {
                                    Text("\(Int(data.cpuUsage))%")
                                        .font(.largeTitle.weight(.bold))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Capsule()
                                        .fill(theme.info.opacity(0.2))
                                        .frame(width: 40, height: 6)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(theme.info)
                                                .frame(width: 40 * min(max(data.cpuUsage / 100, 0), 1), height: 6)
                                        }
                                }

                                // CPU usage breakdown bar
                                GeometryReader { geo in
                                    HStack(spacing: 0) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(hex: "30D158"))
                                            .frame(width: geo.size.width * min(max(cpuService.userUsage / 100, 0), 1))
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color(hex: "FF9F0A"))
                                            .frame(width: geo.size.width * min(max(cpuService.systemUsage / 100, 0), 1))
                                    }
                                }
                                .background(RoundedRectangle(cornerRadius: 2).fill(Color(hex: "98989E").opacity(0.15)))
                                .frame(height: 4)

                                HStack(spacing: 8) {
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(Color(hex: "30D158"))
                                            .frame(width: 5, height: 5)
                                        Text(String(format: "%.0f%%", cpuService.userUsage))
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.textSecondary)
                                    }
                                    HStack(spacing: 3) {
                                        Circle()
                                            .fill(Color(hex: "FF9F0A"))
                                            .frame(width: 5, height: 5)
                                        Text(String(format: "%.0f%%", cpuService.systemUsage))
                                            .font(.system(size: 9))
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("Memory", bundle: .module), icon: "memorychip", color: theme.success) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(memoryUsedText) / \(memoryTotalText)")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)

                                ProgressView(value: data.memoryUsage)
                                    .tint(theme.info)
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("Disk", bundle: .module), icon: "internaldrive", color: theme.warning) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(diskUsedText) \(LumiPluginLocalization.string("used", bundle: .module))")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)

                                Gauge(value: Double(data.diskUsed), in: 0 ... max(Double(data.diskTotal), 1)) {
                                    Text(diskTotalText)
                                }
                                .gaugeStyle(.accessoryLinearCapacity)
                                .tint(theme.info)
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("Battery", bundle: .module), icon: batteryIcon, color: batteryLevelColor) {
                            VStack(alignment: .leading, spacing: 8) {
                                if batteryService.hasBattery {
                                    HStack {
                                        Text("\(Int(batteryService.level * 100))%")
                                            .font(.title.weight(.semibold))
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        if batteryService.isCharging {
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(theme.warning)
                                        }
                                    }

                                    ProgressView(value: batteryService.level)
                                        .tint(batteryLevelColor)

                                    // Enhanced details
                                    HStack(spacing: 12) {
                                        if batteryService.healthPercentage > 0 {
                                            Label {
                                                Text("\(Int(batteryService.healthPercentage))%")
                                                    .font(.caption2)
                                            } icon: {
                                                Image(systemName: "heart.fill")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(batteryHealthColor)
                                        }
                                        if batteryService.cycleCount > 0 {
                                            Label {
                                                Text(String(format: LumiPluginLocalization.string("%d cycles", bundle: .module), batteryService.cycleCount))
                                                    .font(.caption2)
                                            } icon: {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.caption2)
                                            }
                                            .foregroundColor(theme.textSecondary)
                                        }
                                    }
                                } else {
                                    // Desktop Mac without internal battery
                                    HStack {
                                        Image(systemName: "powerplug.fill")
                                            .foregroundColor(.green)
                                        Text(LumiPluginLocalization.string("AC Power", bundle: .module))
                                            .font(.body.weight(.medium))
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                    }
                                    if batteryService.adapterWatts > 0 {
                                        Text(String(format: LumiPluginLocalization.string("Adapter: %@", bundle: .module), batteryService.adapterWattsString))
                                            .font(.caption)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("GPU", bundle: .module), icon: "cpu", color: Color(hex: "BF5AF2")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(gpuService.modelName.isEmpty ? LumiPluginLocalization.string("GPU", bundle: .module) : gpuService.modelName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(theme.textSecondary)

                                HStack(alignment: .bottom) {
                                    Text(String(format: "%.0f%%", gpuService.utilization))
                                        .font(.largeTitle.weight(.bold))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    Capsule()
                                        .fill(Color(hex: "BF5AF2").opacity(0.2))
                                        .frame(width: 40, height: 6)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(Color(hex: "BF5AF2"))
                                                .frame(width: 40 * min(max(gpuService.utilization / 100, 0), 1), height: 6)
                                        }
                                }
                            }
                        }
                    }

                    // External Volumes
                    if !storageService.externalVolumes.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(storageService.externalVolumes) { volume in
                                AppCard {
                                    HStack(spacing: 12) {
                                        Image(systemName: "externaldrive")
                                            .font(.title3)
                                            .foregroundStyle(theme.warning)

                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(volume.name)
                                                .font(.caption.weight(.semibold))
                                                .foregroundColor(theme.textPrimary)

                                            Text("\(volume.usedString) / \(volume.totalString)")
                                                .font(.caption2)
                                                .foregroundColor(theme.textSecondary)

                                            GeometryReader { geo in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(theme.primary.opacity(0.1))
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(volumeUsageColor(volume.usagePercent))
                                                        .frame(width: geo.size.width * min(max(volume.usageFraction, 0), 1))
                                                }
                                            }
                                            .frame(height: 6)
                                        }

                                        Spacer()

                                        Text("\(volume.usagePercent)%")
                                            .font(.title3.weight(.bold))
                                            .foregroundColor(theme.textPrimary)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(theme.textSecondary)
                        Text("\(LumiPluginLocalization.string("Uptime", bundle: .module)): \(formatUptime(data.uptime))")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                GlassDivider()

                VStack(alignment: .leading, spacing: 16) {
                    Label(LumiPluginLocalization.string("Real-time Monitor", bundle: .module), systemImage: "chart.xyaxis.line")
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal)

                    SystemMonitorView()
                }
            }
            .padding()
        }
        .onAppear {
            storageService.startMonitoring()
        }
        .onDisappear {
            data.stopMonitoring()
            storageService.stopMonitoring()
        }
    }

    private var memoryUsedText: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.memoryUsed), countStyle: .memory)
    }

    private var memoryTotalText: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.memoryTotal), countStyle: .memory)
    }

    private var diskUsedText: String {
        ByteCountFormatter.string(fromByteCount: data.diskUsed, countStyle: .file)
    }

    private var diskTotalText: String {
        ByteCountFormatter.string(fromByteCount: data.diskTotal, countStyle: .file)
    }

    // MARK: - Battery Helpers

    private var batteryIcon: String {
        guard batteryService.hasBattery else { return "powerplug.fill" }
        let pct = Int(batteryService.level * 100)
        if batteryService.isCharging {
            return "battery.100.bolt"
        }
        if pct >= 90 { return "battery.100" }
        if pct >= 65 { return "battery.75" }
        if pct >= 40 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    private var batteryLevelColor: Color {
        guard batteryService.hasBattery else { return .green }
        let pct = batteryService.level * 100
        if pct > 50 { return .green }
        if pct > 20 { return .orange }
        return .red
    }

    private var batteryHealthColor: Color {
        let h = batteryService.healthPercentage
        if h >= 80 { return .green }
        if h >= 60 { return .orange }
        return .red
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }

    // MARK: - Storage Helpers

    private func volumeUsageColor(_ percent: Int) -> Color {
        if percent < 70 { return theme.success }
        if percent < 90 { return theme.warning }
        return theme.error
    }
}

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

    public var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(title)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(theme.textSecondary)
                    } icon: {
                        Image(systemName: icon)
                            .foregroundStyle(color)
                    }
                    Spacer()
                }

                content
            }
        }
    }
}
