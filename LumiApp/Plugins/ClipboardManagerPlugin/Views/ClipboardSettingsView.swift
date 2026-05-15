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
                    Text(String(localized: "Unlimited", table: "ClipboardManager")).tag(Int.max)
                }
                .onChange(of: historySize) { _, newValue in
                    store.set(newValue, forKey: historySizeKey)
                }
            }
            
            Section("Data") {
                Button(String(localized: "Clear All History", table: "ClipboardManager")) {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }
                .foregroundColor(Color(hex: "FF453A"))
                
                Text(String(localized: "All data is stored locally in SwiftData database and will not be uploaded to any server.", table: "ClipboardManager"))
                    .font(.caption)
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
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
        .inRootView()
        .withDebugBar()
}
