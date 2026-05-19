import Charts
import SwiftUI
import LumiUI
import DeviceMonitorKit

struct DeviceInfoView: View {
    @StateObject private var data = DeviceData()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Overview
                VStack(spacing: 16) {
                    // Header
                    AppCard(cornerRadius: 20, padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(colors: [Color(hex: "7C6FFF"), Color(hex: "B4A5FF")], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "macbook.and.iphone")
                                    .font(.system(size: 32))
                                    .foregroundStyle(LinearGradient(colors: [Color(hex: "7C6FFF"), Color(hex: "B4A5FF")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(data.deviceName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                                Text(data.osVersion)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            }
                            Spacer()
                        }
                    }

                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DeviceInfoCard(title: "CPU", icon: "cpu", color: Color(hex: "0A84FF")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(data.processorName)
                                    .font(.system(size: 12, weight: .regular))
                                    .lineLimit(1)
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                                HStack(alignment: .bottom) {
                                    Text("\(Int(data.cpuUsage))%")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                    Spacer()
                                    // Simple bar chart representation
                                    Capsule()
                                        .fill(LinearGradient(colors: [Color(hex: "0A1A3E"), Color(hex: "1A2A5E")], startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.2))
                                        .frame(width: 40, height: 6)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(LinearGradient(colors: [Color(hex: "0A1A3E"), Color(hex: "1A2A5E")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                                .frame(width: 40 * (data.cpuUsage / 100.0), height: 6)
                                        }
                                }
                            }
                        }

                        DeviceInfoCard(title: "Memory", icon: "memorychip", color: Color(hex: "30D158")) {
                            VStack(alignment: .leading, spacing: 8) {
                                let used = ByteCountFormatter.string(fromByteCount: Int64(data.memoryUsed), countStyle: .memory)
                                let total = ByteCountFormatter.string(fromByteCount: Int64(data.memoryTotal), countStyle: .memory)

                                Text("\(used) / \(total)")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                                ProgressView(value: data.memoryUsage)
                                    .tint(LinearGradient(colors: [Color(hex: "00D4FF"), Color(hex: "7C6FFF")], startPoint: .leading, endPoint: .trailing))
                            }
                        }

                        DeviceInfoCard(title: "Disk", icon: "internaldrive", color: Color(hex: "FF9F0A")) {
                            VStack(alignment: .leading, spacing: 8) {
                                let used = ByteCountFormatter.string(fromByteCount: data.diskUsed, countStyle: .file)
                                let total = ByteCountFormatter.string(fromByteCount: data.diskTotal, countStyle: .file)

                                Text("\(used) \(String(localized: "used", table: "DeviceInfo"))")
                                    .font(.system(size: 12, weight: .regular))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                                Gauge(value: Double(data.diskUsed), in: 0 ... Double(data.diskTotal)) {
                                    Text(total)
                                }
                                .gaugeStyle(.accessoryLinearCapacity)
                                .tint(LinearGradient(colors: [Color(hex: "00D4FF"), Color(hex: "7C6FFF")], startPoint: .leading, endPoint: .trailing))
                            }
                        }

                        DeviceInfoCard(title: "Battery", icon: "battery.100", color: Color(hex: "7C6FFF")) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(Int(data.batteryLevel * 100))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                                    Spacer()
                                    if data.isCharging {
                                        Image(systemName: "bolt.fill")
                                        .foregroundColor(Color(hex: "FF9F0A"))
                                    }
                                }

                                ProgressView(value: data.batteryLevel)
                                    .tint(Color(hex: "7C6FFF"))
                            }
                        }
                    }

                    // Uptime
                    HStack {
                        Image(systemName: "clock")
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        Text("\(String(localized: "Uptime", table: "DeviceInfo")): \(formatUptime(data.uptime))")
                            .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        Spacer()
                    }
                    .padding(.horizontal)
                }

            GlassDivider()

                // Section 2: Real-time Monitor
                VStack(alignment: .leading, spacing: 16) {
                    Label(String(localized: "Real-time Monitor", table: "DeviceInfo"), systemImage: "chart.xyaxis.line")
                        .font(.system(size: 15, weight: .medium))
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
        AppCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(title)
                            .fontWeight(.medium)
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    } icon: {
                        Image(systemName: icon)
                            .foregroundStyle(
                                AppTheme.Colors.gradient(for: mapColor(color))
                            )
                    }
                    Spacer()
                }

                content
            }
        }
    }
    
    func mapColor(_ color: Color) -> AppTheme.GradientType {
        if color == Color(hex: "0A84FF") { return .blue }
        if color == Color(hex: "30D158") { return .green }
        if color == Color(hex: "FF9F0A") { return .orange }
        if color == Color(hex: "7C6FFF") { return .purple }
        return .primary
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
