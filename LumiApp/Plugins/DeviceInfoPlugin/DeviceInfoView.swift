import Charts
import SwiftUI

struct DeviceInfoView: View {
    @StateObject private var data = DeviceData()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section 1: Overview
                VStack(spacing: 16) {
                    // Header
                    MystiqueGlassCard(cornerRadius: 20, padding: EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)) {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(DesignTokens.Color.gradients.primaryGradient.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "macbook.and.iphone")
                                    .font(.system(size: 32))
                                    .foregroundStyle(DesignTokens.Color.gradients.primaryGradient)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(data.deviceName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text(data.osVersion)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }

                    // Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        DeviceInfoCard(title: String(localized: "CPU"), icon: "cpu", color: .blue) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(data.processorName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .foregroundColor(.secondary)

                                HStack(alignment: .bottom) {
                                    Text("\(Int(data.cpuUsage))%")
                                        .font(.system(size: 24, weight: .bold, design: .rounded))
                                    Spacer()
                                    // Simple bar chart representation
                                    Capsule()
                                        .fill(DesignTokens.Color.gradients.oceanGradient.opacity(0.2))
                                        .frame(width: 40, height: 6)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(DesignTokens.Color.gradients.oceanGradient)
                                                .frame(width: 40 * (data.cpuUsage / 100.0), height: 6)
                                        }
                                }
                            }
                        }

                        DeviceInfoCard(title: String(localized: "Memory"), icon: "memorychip", color: .green) {
                            VStack(alignment: .leading, spacing: 8) {
                                let used = ByteCountFormatter.string(fromByteCount: Int64(data.memoryUsed), countStyle: .memory)
                                let total = ByteCountFormatter.string(fromByteCount: Int64(data.memoryTotal), countStyle: .memory)

                                Text("\(used) / \(total)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                ProgressView(value: data.memoryUsage)
                                    .tint(DesignTokens.Color.gradients.energyGradient)
                            }
                        }

                        DeviceInfoCard(title: "Disk", icon: "internaldrive", color: .orange) {
                            VStack(alignment: .leading, spacing: 8) {
                                let used = ByteCountFormatter.string(fromByteCount: data.diskUsed, countStyle: .file)
                                let total = ByteCountFormatter.string(fromByteCount: data.diskTotal, countStyle: .file)

                                Text("\(used) used")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Gauge(value: Double(data.diskUsed), in: 0 ... Double(data.diskTotal)) {
                                    Text(total)
                                }
                                .gaugeStyle(.accessoryLinearCapacity)
                                .tint(DesignTokens.Color.gradients.energyGradient)
                            }
                        }

                        DeviceInfoCard(title: "Battery", icon: "battery.100", color: .pink) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(Int(data.batteryLevel * 100))%")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Spacer()
                                    if data.isCharging {
                                        Image(systemName: "bolt.fill")
                                        .foregroundColor(.yellow)
                                    }
                                }

                                ProgressView(value: data.batteryLevel)
                                    .tint(DesignTokens.Color.semantic.primary)
                            }
                        }
                    }

                    // Uptime
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                        Text(String(localized: "Uptime: \(formatUptime(data.uptime))"))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                Divider()

                // Section 2: Real-time Monitor
                VStack(alignment: .leading, spacing: 16) {
                    Label("Real-time Monitor", systemImage: "chart.xyaxis.line")
                        .font(.headline)
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
        MystiqueGlassCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label {
                        Text(title)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
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
        if color == .blue { return .blue }
        if color == .green { return .green }
        if color == .orange { return .orange }
        if color == .pink { return .purple }
        return .primary
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(DeviceInfoPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
