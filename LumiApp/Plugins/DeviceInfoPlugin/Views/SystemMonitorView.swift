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
                        color: DesignTokens.Color.semantic.info) {
                ZStack {
                    WaveformView(data: viewModel.metrics.network.downloadHistory, color: DesignTokens.Color.semantic.info, maxVal: 1024*1024*10)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.network.uploadHistory, color: DesignTokens.Color.semantic.primary, maxVal: 1024*1024*5)
                        .opacity(0.6)
                }
            }
            
            // Disk Card
            MonitorCard(title: "Disk I/O", 
                        value: "R: \(viewModel.metrics.disk.readSpeedString) W: \(viewModel.metrics.disk.writeSpeedString)",
                        color: DesignTokens.Color.semantic.warning) {
                ZStack {
                    WaveformView(data: viewModel.metrics.disk.readHistory, color: DesignTokens.Color.semantic.warning, maxVal: 1024*1024*50)
                        .opacity(0.8)
                    WaveformView(data: viewModel.metrics.disk.writeHistory, color: DesignTokens.Color.semantic.error, maxVal: 1024*1024*20)
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
        MystiqueGlassCard(cornerRadius: 16, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    Spacer()
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundColor(color)
                }
                
                content()
                    .frame(height: 100)
                    .background(DesignTokens.Material.glass.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .withDebugBar()
}
