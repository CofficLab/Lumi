import Foundation
import LumiUI
import SwiftUI

struct DeviceInfoView: View {
    @LumiTheme private var theme
    @StateObject private var data = DeviceData()

    var body: some View {
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
                        DeviceInfoCard(title: "CPU", icon: "cpu", color: theme.info) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(data.processorName.isEmpty ? "\(data.coreCount) cores" : data.processorName)
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
                            }
                        }

                        DeviceInfoCard(title: "Memory", icon: "memorychip", color: theme.success) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(memoryUsedText) / \(memoryTotalText)")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)

                                ProgressView(value: data.memoryUsage)
                                    .tint(theme.info)
                            }
                        }

                        DeviceInfoCard(title: "Disk", icon: "internaldrive", color: theme.warning) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("\(diskUsedText) \(PluginDeviceInfoLocalization.string("used"))")
                                    .font(.caption)
                                    .foregroundColor(theme.textSecondary)

                                Gauge(value: Double(data.diskUsed), in: 0 ... max(Double(data.diskTotal), 1)) {
                                    Text(diskTotalText)
                                }
                                .gaugeStyle(.accessoryLinearCapacity)
                                .tint(theme.info)
                            }
                        }

                        DeviceInfoCard(title: "Battery", icon: "battery.100", color: theme.info) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(Int(data.batteryLevel * 100))%")
                                        .font(.title.weight(.semibold))
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if data.isCharging {
                                        Image(systemName: "bolt.fill")
                                            .foregroundColor(theme.warning)
                                    }
                                }

                                ProgressView(value: data.batteryLevel)
                                    .tint(theme.info)
                            }
                        }
                    }

                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(theme.textSecondary)
                        Text("\(PluginDeviceInfoLocalization.string("Uptime")): \(formatUptime(data.uptime))")
                            .font(.caption)
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                GlassDivider()

                VStack(alignment: .leading, spacing: 16) {
                    Label(PluginDeviceInfoLocalization.string("Real-time Monitor"), systemImage: "chart.xyaxis.line")
                        .font(.body.weight(.semibold))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal)

                    SystemMonitorView()
                }
            }
            .padding()
        }
        .onDisappear {
            data.stopMonitoring()
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

    private func formatUptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

private struct DeviceInfoCard<Content: View>: View {
    @LumiTheme private var theme

    let title: LocalizedStringKey
    let icon: String
    let color: Color
    let content: Content

    init(title: LocalizedStringKey, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
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
