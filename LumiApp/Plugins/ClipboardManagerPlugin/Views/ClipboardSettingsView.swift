import LumiUI
import SwiftUI

struct ClipboardSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var monitor = ClipboardMonitor.shared
    @State private var historySize: Int = 500
    @State private var isMonitoringEnabled: Bool = true

    private let store = ClipboardManagerPluginLocalStore.shared
    private let monitoringKey = "ClipboardMonitoringEnabled"
    private let historySizeKey = "ClipboardHistorySize"

    var body: some View {
        PluginSettingsScaffold(
            String(localized: "Clipboard Manager", table: "ClipboardManager"),
            subtitle: String(localized: "Monitor clipboard history locally on this device.", table: "ClipboardManager")
        ) {
            generalSection
            dataSection
        }
        .task {
            isMonitoringEnabled = store.bool(forKey: monitoringKey)
            historySize = store.integer(forKey: historySizeKey)
            if historySize == 0 {
                historySize = 500
            }
        }
    }

    private var generalSection: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "General", table: "ClipboardManager"),
                spacing: 12
            ) {
                AppSettingsToggleRow(
                    String(localized: "Enable Clipboard Monitoring", table: "ClipboardManager"),
                    systemImage: "doc.on.clipboard",
                    isOn: $isMonitoringEnabled
                )
                .onChange(of: isMonitoringEnabled) { _, newValue in
                    store.set(newValue, forKey: monitoringKey)
                    if newValue {
                        monitor.startMonitoring()
                    } else {
                        monitor.stopMonitoring()
                    }
                }

                AppSettingsPickerRow(
                    String(localized: "History Size", table: "ClipboardManager"),
                    systemImage: "clock.arrow.circlepath",
                    selection: $historySize
                ) {
                    Text("100").tag(100)
                    Text("500").tag(500)
                    Text("1000").tag(1000)
                    Text(String(localized: "Unlimited", table: "ClipboardManager")).tag(Int.max)
                }
                .onChange(of: historySize) { _, newValue in
                    store.set(newValue, forKey: historySizeKey)
                }
            }
        }
    }

    private var dataSection: some View {
        AppCard {
            AppSettingsSection(
                title: String(localized: "Data", table: "ClipboardManager"),
                spacing: 12
            ) {
                AppButton(
                    String(localized: "Clear All History", table: "ClipboardManager"),
                    style: .destructive,
                    fillsWidth: true
                ) {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }

                Text(String(localized: "All data is stored locally in SwiftData database and will not be uploaded to any server.", table: "ClipboardManager"))
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

#Preview("App") {
    ClipboardSettingsView()
        .inRootView()
        .frame(width: 520, height: 480)
}
