import SwiftUI

struct ClipboardSettingsView: View {
    @StateObject private var monitor = ClipboardMonitor.shared
    @State private var historySize: Int = 500
    @State private var isMonitoringEnabled: Bool = true
    
    private let store = ClipboardManagerPluginLocalStore.shared
    private let monitoringKey = "ClipboardMonitoringEnabled"
    private let historySizeKey = "ClipboardHistorySize"
    
    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable Clipboard Monitoring", isOn: $isMonitoringEnabled)
                    .onChange(of: isMonitoringEnabled) { _, newValue in
                        store.set(newValue, forKey: monitoringKey)
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
                .onChange(of: historySize) { _, newValue in
                    store.set(newValue, forKey: historySizeKey)
                }
            }
            
            Section("Data") {
                Button("Clear All History") {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }
                .foregroundColor(DesignTokens.Color.semantic.error)
                
                Text("All data is stored locally in SwiftData database and will not be uploaded to any server.")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }
        }
        .padding()
        .task {
            // Load settings from store
            isMonitoringEnabled = store.bool(forKey: monitoringKey)
            historySize = store.integer(forKey: historySizeKey)
            if historySize == 0 {
                historySize = 500
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
