import SwiftUI

struct ClipboardSettingsView: View {
    @StateObject private var monitor = ClipboardMonitor.shared
    @AppStorage("ClipboardHistorySize") private var historySize: Int = 500
    @AppStorage("ClipboardMonitoringEnabled") private var isMonitoringEnabled: Bool = true
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable Clipboard Monitoring", isOn: $isMonitoringEnabled)
                    .onChange(of: isMonitoringEnabled) { newValue in
                        if newValue {
                            monitor.startMonitoring()
                        } else {
                            monitor.stopMonitoring()
                        }
                    }
                
                Picker("History Size", selection: $historySize) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text("Unlimited").tag(Int.max)
                }
            }
            
            Section("Data") {
                Button("Clear All History") {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }
                .foregroundColor(.red)
                
                Text("All data is stored locally and will not be uploaded to any server.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
