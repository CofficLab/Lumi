import LumiUI
import SwiftUI

public struct ClipboardSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var historySize: Int = 500
    @State private var isMonitoringEnabled: Bool = true

    private let store = ClipboardManagerPluginLocalStore.shared
    private let monitoringKey = "ClipboardMonitoringEnabled"
    private let historySizeKey = "ClipboardHistorySize"

    public var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Clipboard Manager"),
            subtitle: pluginLocalization.string("Monitor clipboard history locally on this device."),
            showHeader: false
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
                title: pluginLocalization.string("General"),
                spacing: 12
            ) {
                AppSettingsToggleRow(
                    pluginLocalization.string("Enable Clipboard Monitoring"),
                    systemImage: "doc.on.clipboard",
                    isOn: $isMonitoringEnabled
                )
                .onChange(of: isMonitoringEnabled) { _, newValue in
                    store.set(newValue, forKey: monitoringKey)
                }

                AppSettingsPickerRow(
                    pluginLocalization.string("History Size"),
                    systemImage: "clock.arrow.circlepath",
                    selection: $historySize
                ) {
                    Text(verbatim: pluginLocalization.string("100")).tag(100)
                    Text(verbatim: pluginLocalization.string("500")).tag(500)
                    Text(verbatim: pluginLocalization.string("1000")).tag(1000)
                    Text(pluginLocalization.string("Unlimited")).tag(Int.max)
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
                title: pluginLocalization.string("Data"),
                spacing: 12
            ) {
                AppButton(
                    pluginLocalization.string("Clear All History"),
                    style: .destructive,
                    fillsWidth: true
                ) {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }

                Text(pluginLocalization.string("All data is stored locally in SwiftData database and will not be uploaded to any server."))
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
