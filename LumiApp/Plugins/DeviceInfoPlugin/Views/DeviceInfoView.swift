import Charts
import SwiftUI
import LumiUI
import DeviceMonitorKit

struct DeviceInfoView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var data = DeviceData()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Overview
                VStack(spacing: 16) {
                    // Header
                    AppCard {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(theme.primary.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "macbook.and.iphone")
                                    .font(.appLargeTitle)
                                    .foregroundStyle(theme.primary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(data.deviceName)
                                    .font(.appTitle)
                                    .foregroundColor(theme.textPrimary)
                                Text(data.osVersion)
                                    .font(.appBody)
                                    .foregroundColor(theme.textSecondary)
                            }
                            Spacer()
                        }
                    }

                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DeviceInfoCard(title: "CPU", icon: "cpu", color: .blue) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(data.processorName)
                                    .font(.appCaption)
                                    .lineLimit(1)
                                    .foregroundColor(theme.textSecondary)

                                HStack(alignment: .bottom) {
                                    Text("\(Int(data.cpuUsage))%")
                                        .font(.appLargeTitle)
                                    Spacer()
                                    // Simple bar chart representation
                                    Capsule()
                                        .fill(theme.primary.opacity(0.2))
                                        .frame(width: 40, height: 6)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(theme.primary)
                                                .frame(width: 40 * (data.cpuUsage / 100.0), height: 6)
                                        }
                                }
                            }
                        }

                        DeviceInfoCard(title: "Memory", icon: "memorychip", color: .green) {
                            VStack(alignment: .leading, spacing: 8) {
                                let used = ByteCountFormatter.string(fromByteCount: Int64(data.memoryUsed), countStyle: .memory)
                                let total = ByteCountFormatter.string(fromByteCount: Int64(data.memoryTotal), countStyle: .memory)

                                Text("\(used) / \(total)")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)

                                ProgressView(value: data.memoryUsage)
                                    .tint(theme.primary)
                            }
                        }

                        DeviceInfoCard(title: "Disk", icon: "internaldrive", color: .orange) {
                            VStack(alignment: .leading, spacing: 8) {
                                let used = ByteCountFormatter.string(fromByteCount: data.diskUsed, countStyle: .file)
                                let total = ByteCountFormatter.string(fromByteCount: data.diskTotal, countStyle: .file)

                                Text("\(used) \(String(localized: "used", table: "DeviceInfo"))")
                                    .font(.appCaption)
                                    .foregroundColor(theme.textSecondary)

                                Gauge(value: Double(data.diskUsed), in: 0 ... Double(data.diskTotal)) {
                                    Text(total)
                                }
                                .gaugeStyle(.accessoryLinearCapacity)
                                .tint(theme.primary)
                            }
                        }

                        DeviceInfoCard(title: "Battery", icon: "battery.100", color: .purple) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(Int(data.batteryLevel * 100))%")
                                        .font(.appTitle)
                                        .foregroundColor(theme.textPrimary)
                                    Spacer()
                                    if data.isCharging {
                                        Image(systemName: "bolt.fill")
                                        .foregroundColor(theme.warning)
                                    }
                                }

                                ProgressView(value: data.batteryLevel)
                                    .tint(theme.primary)
                            }
                        }
                    }

                    // Uptime
                    HStack {
                        Image(systemName: "clock")
                        .foregroundColor(theme.textSecondary)
                        Text("\(String(localized: "Uptime", table: "DeviceInfo")): \(formatUptime(data.uptime))")
                            .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

            GlassDivider()

                // Section 2: Real-time Monitor
                VStack(alignment: .leading, spacing: 16) {
                    Label(String(localized: "Real-time Monitor", table: "DeviceInfo"), systemImage: "chart.xyaxis.line")
                        .font(.appBody)
                        .padding(.horizontal)
                    
                    SystemMonitorView()
                }
            }
            .padding()
        }
    }

    private func formatUptime(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

struct DeviceInfoCard<Content: View>: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

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
                            .font(.appCaptionEmphasized)
                            .foregroundColor(theme.textSecondary)
                    } icon: {
                        Image(systemName: icon)
                            .foregroundStyle(mapColor(color))
                    }
                    Spacer()
                }

                content
            }
        }
    }
    
    func mapColor(_ color: Color) -> Color {
        if color == .blue { return theme.info }
        if color == .green { return theme.success }
        if color == .orange { return theme.warning }
        if color == .purple { return theme.primary }
        return theme.textSecondary
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
