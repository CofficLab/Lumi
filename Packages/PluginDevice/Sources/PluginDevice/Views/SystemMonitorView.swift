import SwiftUI
import LumiUI

struct SystemMonitorView: View {
    @LumiTheme private var theme

    @ObservedObject private var viewModel: SystemMonitorViewModel
    @ObservedObject private var gpuViewModel: GPUManagerViewModel
    @ObservedObject private var batteryViewModel: BatteryManagerViewModel

    init(viewModel: SystemMonitorViewModel, gpuViewModel: GPUManagerViewModel, batteryViewModel: BatteryManagerViewModel) {
        self.viewModel = viewModel
        self.gpuViewModel = gpuViewModel
        self.batteryViewModel = batteryViewModel
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
            // CPU Card
            MonitorCard(title: LumiPluginLocalization.string("CPU", bundle: .module), 
                        value: viewModel.metrics.cpuUsage.description,
                        color: viewModel.cpuColor) {
                WaveformView(data: viewModel.metrics.cpuUsage.history, color: viewModel.cpuColor)
            }
            
            // Memory Card
            MonitorCard(title: LumiPluginLocalization.string("Memory", bundle: .module), 
                        value: viewModel.metrics.memoryUsage.description,
                        color: viewModel.memoryColor) {
                WaveformView(data: viewModel.metrics.memoryUsage.history, color: viewModel.memoryColor)
            }
            
            // GPU Card
            MonitorCard(title: LumiPluginLocalization.string("GPU", bundle: .module),
                        value: String(format: "%.0f%%", gpuViewModel.utilization),
                        color: gpuColor) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gpuViewModel.modelName.isEmpty ? LumiPluginLocalization.string("GPU", bundle: .module) : gpuViewModel.modelName)
                        .font(.system(size: 9))
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LumiPluginLocalization.string("Memory", bundle: .module))
                                .font(.system(size: 8))
                                .foregroundColor(theme.textSecondary)
                            Text(gpuViewModel.usedMemory)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(gpuColor)
                        }

                        if gpuViewModel.temperature > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LumiPluginLocalization.string("Temperature", bundle: .module))
                                    .font(.system(size: 8))
                                    .foregroundColor(theme.textSecondary)
                                Text(String(format: "%.0f°C", gpuViewModel.temperature))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(gpuColor)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(8)
            }

            // Network Card
            MonitorCard(title: LumiPluginLocalization.string("Network", bundle: .module),
                        value: "↓\(viewModel.metrics.network.downloadSpeedString) ↑\(viewModel.metrics.network.uploadSpeedString)",
                        color: theme.info) {
                ZStack {
                    WaveformView(data: viewModel.metrics.network.downloadHistory, color: theme.info, maxVal: 1024*1024*10)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.network.uploadHistory, color: theme.primary, maxVal: 1024*1024*5)
                        .opacity(0.6)
                }
            }

            // Disk Card
            MonitorCard(title: LumiPluginLocalization.string("Disk I/O", bundle: .module),
                        value: String(format: LumiPluginLocalization.string("R: %@ W: %@", bundle: .module), viewModel.metrics.disk.readSpeedString, viewModel.metrics.disk.writeSpeedString),
                        color: theme.warning) {
                ZStack {
                    WaveformView(data: viewModel.metrics.disk.readHistory, color: theme.warning, maxVal: 1024*1024*50)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.disk.writeHistory, color: theme.error, maxVal: 1024*1024*20)
                        .opacity(0.6)
                }
            }

            // Battery Card
            if batteryViewModel.hasBattery {
                MonitorCard(title: LumiPluginLocalization.string("Battery", bundle: .module),
                            value: batteryMonitorValue,
                            color: batteryLevelColor) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LumiPluginLocalization.string("Health", bundle: .module))
                                    .font(.system(size: 8))
                                    .foregroundColor(theme.textSecondary)
                                Text("\(Int(batteryViewModel.healthPercentage))%")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(batteryHealthColor)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(LumiPluginLocalization.string("Cycles", bundle: .module))
                                    .font(.system(size: 8))
                                    .foregroundColor(theme.textSecondary)
                                Text("\(batteryViewModel.cycleCount)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                            }

                            if batteryViewModel.temperature > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LumiPluginLocalization.string("Temperature", bundle: .module))
                                        .font(.system(size: 8))
                                        .foregroundColor(theme.textSecondary)
                                    Text(String(format: "%.1f°C", batteryViewModel.temperature))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(batteryTemperatureColor)
                                }
                            }

                            if batteryViewModel.watts > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LumiPluginLocalization.string("Power", bundle: .module))
                                        .font(.system(size: 8))
                                        .foregroundColor(theme.textSecondary)
                                    Text(batteryViewModel.wattsString)
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(batteryLevelColor)
                                }
                            }
                        }

                        Spacer()

                        // Battery bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(theme.textTertiary.opacity(0.2))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(batteryLevelColor)
                                    .frame(width: geo.size.width * min(max(batteryViewModel.level, 0), 1), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(8)
                }
            }
        }
        .padding()
    }
    
    private var gpuColor: Color {
        MetricStatusScale.from(percentage: gpuViewModel.utilization).color(in: theme)
    }

    private var batteryMonitorValue: String {
        let pct = Int(batteryViewModel.level * 100)
        if batteryViewModel.isCharging {
            return "\(pct)% ⚡"
        }
        return "\(pct)%"
    }

    private var batteryLevelColor: Color {
        MetricStatus.batteryLevel(batteryViewModel.level).color(in: theme)
    }

    private var batteryHealthColor: Color {
        MetricStatus.batteryHealth(batteryViewModel.healthPercentage).color(in: theme)
    }

    private var batteryTemperatureColor: Color {
        MetricStatus.temperature(batteryViewModel.temperature).color(in: theme)
    }
}

struct MonitorCard<Content: View>: View {
    @LumiTheme private var theme

    let title: String
    let value: String
    let color: Color
    let content: () -> Content

    var body: some View {
        AppCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                    Spacer()
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(color)
                }

                content()
                    .frame(height: 100)
                    .background(theme.textTertiary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
