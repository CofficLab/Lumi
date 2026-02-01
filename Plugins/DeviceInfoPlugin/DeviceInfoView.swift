import SwiftUI
import Charts

struct DeviceInfoView: View {
    @StateObject private var data = DeviceData()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "macbook.and.iphone")
                        .font(.system(size: 32))
                        .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    
                    VStack(alignment: .leading) {
                        Text(data.deviceName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(data.osVersion)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Material.ultraThinMaterial)
                .cornerRadius(12)
                
                // Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    DeviceInfoCard(title: "CPU", icon: "cpu", color: .blue) {
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
                                    .fill(Color.blue.opacity(0.2))
                                    .frame(width: 40, height: 6)
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.blue)
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
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ProgressView(value: data.memoryUsage)
                                .tint(.green)
                        }
                    }
                    
                    DeviceInfoCard(title: "Disk", icon: "internaldrive", color: .orange) {
                        VStack(alignment: .leading, spacing: 8) {
                            let used = ByteCountFormatter.string(fromByteCount: data.diskUsed, countStyle: .file)
                            let total = ByteCountFormatter.string(fromByteCount: data.diskTotal, countStyle: .file)
                            
                            Text("\(used) used")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Gauge(value: Double(data.diskUsed), in: 0...Double(data.diskTotal)) {
                                Text(total)
                            }
                            .gaugeStyle(.accessoryLinearCapacity)
                            .tint(.orange)
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
                                .tint(data.batteryLevel < 0.2 ? .red : .pink)
                        }
                    }
                }
                
                // Uptime
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.secondary)
                    Text("Uptime: \(formatUptime(data.uptime))")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .frame(width: 350, height: 400)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(title)
                        .fontWeight(.medium)
                } icon: {
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
