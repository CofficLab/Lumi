import SwiftUI
import LumiUI

struct SystemMonitorView: View {
    @StateObject private var viewModel = SystemMonitorViewModel()
    @ObservedObject private var gpuService = GPUService.shared
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
            // CPU Card
            MonitorCard(title: "CPU", 
                        value: viewModel.metrics.cpuUsage.description,
                        color: viewModel.cpuColor) {
                WaveformView(data: viewModel.metrics.cpuUsage.history, color: viewModel.cpuColor)
            }
            
            // Memory Card
            MonitorCard(title: "Memory", 
                        value: viewModel.metrics.memoryUsage.description,
                        color: viewModel.memoryColor) {
                WaveformView(data: viewModel.metrics.memoryUsage.history, color: viewModel.memoryColor)
            }
            
            // GPU Card
            MonitorCard(title: "GPU", 
                        value: String(format: "%.0f%%", gpuService.utilization),
                        color: gpuColor) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(gpuService.modelName.isEmpty ? "GPU" : gpuService.modelName)
                        .font(.system(size: 9))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PluginDeviceInfoLocalization.string("Memory"))
                                .font(.system(size: 8))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            Text(gpuService.usedMemoryString)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(gpuColor)
                        }
                        
                        if gpuService.temperature > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(PluginDeviceInfoLocalization.string("Temperature"))
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
            MonitorCard(title: "Network", 
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
            MonitorCard(title: "Disk I/O", 
                        value: String(format: PluginDeviceInfoLocalization.string("R: %@ W: %@"), viewModel.metrics.disk.readSpeedString, viewModel.metrics.disk.writeSpeedString),
                        color: Color(hex: "FF9F0A")) {
                ZStack {
                    WaveformView(data: viewModel.metrics.disk.readHistory, color: Color(hex: "FF9F0A"), maxVal: 1024*1024*50)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.disk.writeHistory, color: Color(hex: "FF453A"), maxVal: 1024*1024*20)
                        .opacity(0.6)
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.startMonitoring()
            gpuService.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
            gpuService.stopMonitoring()
        }
    }
    
    private var gpuColor: Color {
        let value = gpuService.utilization
        if value < 60 { return Color(hex: "BF5AF2") }
        if value < 85 { return Color(hex: "FF9F0A") }
        return Color(hex: "FF453A")
    }
}

struct MonitorCard<Content: View>: View {
    let title: LocalizedStringKey
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

