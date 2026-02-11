import SwiftUI

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
                        color: .blue) {
                ZStack {
                    WaveformView(data: viewModel.metrics.network.downloadHistory, color: .blue, maxVal: 1024*1024*10) // Approx 10MB scale
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.network.uploadHistory, color: .purple, maxVal: 1024*1024*5) // Approx 5MB scale
                        .opacity(0.6)
                }
            }
            
            // Disk Card
            MonitorCard(title: "Disk I/O", 
                        value: "R: \(viewModel.metrics.disk.readSpeedString) W: \(viewModel.metrics.disk.writeSpeedString)",
                        color: .orange) {
                ZStack {
                    WaveformView(data: viewModel.metrics.disk.readHistory, color: .orange, maxVal: 1024*1024*50) // Approx 50MB scale
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.disk.writeHistory, color: .red, maxVal: 1024*1024*20) // Approx 20MB scale
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
    let title: String
    let value: String
    let color: Color
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(color)
            }
            
            content()
                .frame(height: 100)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
