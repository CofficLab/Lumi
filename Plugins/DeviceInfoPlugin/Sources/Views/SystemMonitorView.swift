import SwiftUI
import LumiUI

struct SystemMonitorView: View {
    @StateObject private var viewModel = SystemMonitorViewModel()
    
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
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
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

