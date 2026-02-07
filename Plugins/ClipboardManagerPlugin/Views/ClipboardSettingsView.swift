import SwiftUI

struct ClipboardSettingsView: View {
    @StateObject private var monitor = ClipboardMonitor.shared
    @AppStorage("ClipboardHistorySize") private var historySize: Int = 500
    @AppStorage("ClipboardMonitoringEnabled") private var isMonitoringEnabled: Bool = true
    
    var body: some View {
        Form {
            Section("通用") {
                Toggle("启用剪贴板监听", isOn: $isMonitoringEnabled)
                    .onChange(of: isMonitoringEnabled) { newValue in
                        if newValue {
                            monitor.startMonitoring()
                        } else {
                            monitor.stopMonitoring()
                        }
                    }
                
                Picker("历史记录数量", selection: $historySize) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("无限制").tag(Int.max)
                }
            }
            
            Section("数据") {
                Button("清空所有历史记录") {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }
                .foregroundColor(.red)
                
                Text("所有数据仅存储在本地，不会上传到任何服务器。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
