import SwiftUI
import LumiUI

struct SystemMonitorView: View {
    @StateObject private var viewModel = SystemMonitorViewModel()
    @ObservedObject private var gpuService = GPUService.shared
    @ObservedObject private var batteryService = BatteryService.shared
    
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
                        value: String(format: "%.0f%%", gpuService.utilization),
                        color: gpuColor) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gpuService.modelName.isEmpty ? LumiPluginLocalization.string("GPU", bundle: .module) : gpuService.modelName)
                        .font(.system(size: 9))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(LumiPluginLocalization.string("Memory", bundle: .module))
                                .font(.system(size: 8))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            Text(gpuService.usedMemoryString)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(gpuColor)
                        }
                        
                        if gpuService.temperature > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LumiPluginLocalization.string("Temperature", bundle: .module))
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                Text(String(format: "%.0f°C", gpuService.temperature))
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
                        color: Color(hex: "0A84FF")) {
                ZStack {
                    WaveformView(data: viewModel.metrics.network.downloadHistory, color: Color(hex: "0A84FF"), maxVal: 1024*1024*10)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.network.uploadHistory, color: Color(hex: "7C6FFF"), maxVal: 1024*1024*5)
                        .opacity(0.6)
                }
            }
            
            // Disk Card
            MonitorCard(title: LumiPluginLocalization.string("Disk I/O", bundle: .module), 
                        value: String(format: LumiPluginLocalization.string("R: %@ W: %@", bundle: .module), viewModel.metrics.disk.readSpeedString, viewModel.metrics.disk.writeSpeedString),
                        color: Color(hex: "FF9F0A")) {
                ZStack {
                    WaveformView(data: viewModel.metrics.disk.readHistory, color: Color(hex: "FF9F0A"), maxVal: 1024*1024*50)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.disk.writeHistory, color: Color(hex: "FF453A"), maxVal: 1024*1024*20)
                        .opacity(0.6)
                }
            }
            
            // Battery Card
            if batteryService.hasBattery {
                MonitorCard(title: LumiPluginLocalization.string("Battery", bundle: .module),
                            value: batteryMonitorValue,
                            color: batteryLevelColor) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LumiPluginLocalization.string("Health", bundle: .module))
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                Text("\(Int(batteryService.healthPercentage))%")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(batteryHealthColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(LumiPluginLocalization.string("Cycles", bundle: .module))
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                Text("\(batteryService.cycleCount)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(Color.adaptive(light: "3C3C43", dark: "EBEBF5"))
                            }
                            
                            if batteryService.temperature > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LumiPluginLocalization.string("Temperature", bundle: .module))
                                        .font(.system(size: 8))
                                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                    Text(String(format: "%.1f°C", batteryService.temperature))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(batteryTemperatureColor)
                                }
                            }
                            
                            if batteryService.watts > 0 {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LumiPluginLocalization.string("Power", bundle: .module))
                                        .font(.system(size: 8))
                                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                    Text(batteryService.wattsString)
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
                                    .fill(Color.adaptive(light: "E5E5EA", dark: "38383A"))
                                    .frame(height: 8)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(batteryLevelColor)
                                    .frame(width: geo.size.width * min(max(batteryService.level, 0), 1), height: 8)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(8)
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.startMonitoring()
            gpuService.startMonitoring()
            batteryService.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
            gpuService.stopMonitoring()
            batteryService.stopMonitoring()
        }
    }
    
    private var gpuColor: Color {
        let value = gpuService.utilization
        if value < 60 { return Color(hex: "BF5AF2") }
        if value < 85 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
    
    private var batteryMonitorValue: String {
        let pct = Int(batteryService.level * 100)
        if batteryService.isCharging {
            return "\(pct)% ⚡"
        }
        return "\(pct)%"
    }
    
    private var batteryLevelColor: Color {
        let pct = batteryService.level * 100
        if pct > 50 { return Color(hex: "30D158") }
        if pct > 20 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
    
    private var batteryHealthColor: Color {
        let h = batteryService.healthPercentage
        if h >= 80 { return Color(hex: "30D158") }
        if h >= 60 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
    
    private var batteryTemperatureColor: Color {
        let t = batteryService.temperature
        if t < 35 { return Color(hex: "30D158") }
        if t < 45 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
}

struct MonitorCard<Content: View>: View {
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
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    Spacer()
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(color)
                }
                
                content()
                    .frame(height: 100)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

