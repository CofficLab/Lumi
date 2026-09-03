import Foundation
import LumiUI
import SwiftUI

public struct DeviceInfoView: View {
    @LumiTheme private var theme
    @ObservedObject private var viewModels: DevicePluginViewModels

    init(viewModels: DevicePluginViewModels) {
        self.viewModels = viewModels
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    AppCard {
                        HStack(spacing: 12) {
                            Image(systemName: "macbook.and.iphone")
                                .font(.title)
                                .foregroundStyle(theme.primary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModels.deviceData.deviceName)
                                    .font(.appBody)
                                    .fontWeight(.semibold)
                                    .foregroundColor(theme.textPrimary)
                                Text(viewModels.deviceData.osVersion)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)
                            }

                            Spacer()
                        }
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DeviceInfoCard(title: LumiPluginLocalization.string("CPU", bundle: .module), icon: "cpu", color: theme.info) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(viewModels.deviceData.processorName.isEmpty ? String(format: LumiPluginLocalization.string("%d cores", bundle: .module), viewModels.deviceData.coreCount) : viewModels.deviceData.processorName)
                                    .font(.appCaption)
                                    .lineLimit(1)
                                    .foregroundColor(theme.textSecondary)

                                Text("\(Int(viewModels.deviceData.cpuUsage))%")
                                    .font(.appSectionTitle)
                                    .foregroundColor(theme.textPrimary)

                                ProgressView(value: viewModels.deviceData.cpuUsage, total: 100)
                                    .tint(theme.info)

                                // User / system breakdown (compact)
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Text(LumiPluginLocalization.string("User", bundle: .module))
                                            .font(.appCaption)
                                            .foregroundColor(theme.textSecondary)
                                        Text(String(format: "%.0f%%", viewModels.cpu.userUsage))
                                            .font(.appCaption)
                                            .foregroundColor(theme.success)
                                    }
                                    HStack(spacing: 4) {
                                        Text(LumiPluginLocalization.string("System", bundle: .module))
                                            .font(.appCaption)
                                            .foregroundColor(theme.textSecondary)
                                        Text(String(format: "%.0f%%", viewModels.cpu.systemUsage))
                                            .font(.appCaption)
                                            .foregroundColor(theme.warning)
                                    }
                                    Spacer()
                                }
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("Memory", bundle: .module), icon: "memorychip", color: theme.success) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(memoryUsedText) / \(memoryTotalText)")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)

                                ProgressView(value: viewModels.deviceData.memoryUsage, total: 1.0)
                                    .tint(theme.info)
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("Disk", bundle: .module), icon: "internaldrive", color: theme.warning) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(diskUsedText) \(LumiPluginLocalization.string("used", bundle: .module))")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)

                                ProgressView(
                                    value: Double(viewModels.deviceData.diskUsed),
                                    total: max(Double(viewModels.deviceData.diskTotal), 1)
                                )
                                .tint(theme.info)

                                Text(diskTotalText)
                                    .font(.appCaption)
                                    .foregroundColor(theme.textTertiary)
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("Battery", bundle: .module), icon: batteryIcon, color: batteryLevelColor) {
                            VStack(alignment: .leading, spacing: 8) {
                                if viewModels.battery.hasBattery {
                                    HStack {
                                        Text("\(Int(viewModels.battery.level * 100))%")
                                            .font(.appSectionTitle)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        if viewModels.battery.isCharging {
                                            Image(systemName: "bolt.fill")
                                                .foregroundColor(theme.warning)
                                        }
                                    }

                                    ProgressView(value: viewModels.battery.level)
                                        .tint(batteryLevelColor)

                                    HStack(spacing: 12) {
                                        if viewModels.battery.healthPercentage > 0 {
                                            Label {
                                                Text("\(Int(viewModels.battery.healthPercentage))%")
                                                    .font(.appCaption)
                                            } icon: {
                                                Image(systemName: "heart.fill")
                                                    .font(.appCaption)
                                            }
                                            .foregroundColor(batteryHealthColor)
                                        }
                                        if viewModels.battery.cycleCount > 0 {
                                            Label {
                                                Text(String(format: LumiPluginLocalization.string("%d cycles", bundle: .module), viewModels.battery.cycleCount))
                                                    .font(.appCaption)
                                            } icon: {
                                                Image(systemName: "arrow.triangle.2.circlepath")
                                                    .font(.appCaption)
                                            }
                                            .foregroundColor(theme.textSecondary)
                                        }
                                    }
                                } else {
                                    // Desktop Mac without internal battery
                                    HStack {
                                        Image(systemName: "powerplug.fill")
                                            .foregroundColor(theme.success)
                                        Text(LumiPluginLocalization.string("AC Power", bundle: .module))
                                            .font(.appBody)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                    }
                                    if viewModels.battery.adapterWatts > 0 {
                                        Text(String(format: LumiPluginLocalization.string("Adapter: %@", bundle: .module), viewModels.battery.adapterWattsString))
                                            .font(.appCaption)
                                            .foregroundColor(theme.textSecondary)
                                    }
                                }
                            }
                        }

                        DeviceInfoCard(title: LumiPluginLocalization.string("GPU", bundle: .module), icon: "cpu", color: theme.info) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(viewModels.gpu.modelName.isEmpty ? LumiPluginLocalization.string("GPU", bundle: .module) : viewModels.gpu.modelName)
                                    .font(.appCaption)
                                    .lineLimit(1)
                                    .foregroundColor(theme.textSecondary)

                                Text(String(format: "%.0f%%", viewModels.gpu.utilization))
                                    .font(.appSectionTitle)
                                    .foregroundColor(theme.textPrimary)

                                ProgressView(value: viewModels.gpu.utilization, total: 100)
                                    .tint(theme.info)
                            }
                        }
                    }

                    // External Volumes
                    if !viewModels.storage.externalVolumes.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(viewModels.storage.externalVolumes) { volume in
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

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(theme.textSecondary)
                        Text("\(LumiPluginLocalization.string("Uptime", bundle: .module)): \(formatUptime(viewModels.deviceData.uptime))")
                            .font(.appCaption)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
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

                    SystemMonitorView(viewModel: viewModels.systemMonitor, gpuViewModel: viewModels.gpu, batteryViewModel: viewModels.battery)
                }
            }
            .padding()
        }
        // 让容器页里的 AppCard 走 subtle 风格，移除默认的 glass shadow / glow，
        // 与 RailView 中其他扁平卡片保持一致。
        .environment(\.appSettingsCardStyleOverride, .subtle)
    }

    private var memoryUsedText: String {
        ByteCountFormatter.string(fromByteCount: Int64(viewModels.deviceData.memoryUsed), countStyle: .memory)
    }

    private var memoryTotalText: String {
        ByteCountFormatter.string(fromByteCount: Int64(viewModels.deviceData.memoryTotal), countStyle: .memory)
    }

    private var diskUsedText: String {
        ByteCountFormatter.string(fromByteCount: viewModels.deviceData.diskUsed, countStyle: .file)
    }

    private var diskTotalText: String {
        ByteCountFormatter.string(fromByteCount: viewModels.deviceData.diskTotal, countStyle: .file)
    }

    // MARK: - Battery Helpers

    private var batteryIcon: String {
        guard viewModels.battery.hasBattery else { return "powerplug.fill" }
        let pct = Int(viewModels.battery.level * 100)
        if viewModels.battery.isCharging {
            return "battery.100.bolt"
        }
        if pct >= 90 { return "battery.100" }
        if pct >= 65 { return "battery.75" }
        if pct >= 40 { return "battery.50" }
        if pct >= 15 { return "battery.25" }
        return "battery.0"
    }

    private var batteryLevelColor: Color {
        guard viewModels.battery.hasBattery else { return theme.success }
        return MetricStatus.batteryLevel(viewModels.battery.level).color(in: theme)
    }

    private var batteryHealthColor: Color {
        MetricStatus.batteryHealth(viewModels.battery.healthPercentage).color(in: theme)
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

    public var body: some View {
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
