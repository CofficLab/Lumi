import LumiUI
import SwiftUI

public struct ClipboardSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var monitor = ClipboardMonitor.shared
    @State private var historySize: Int = 500
    @State private var isMonitoringEnabled: Bool = true

    private let store = ClipboardManagerPluginLocalStore.shared
    private let monitoringKey = "ClipboardMonitoringEnabled"
    private let historySizeKey = "ClipboardHistorySize"

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Clipboard Manager", bundle: .module),
            subtitle: LumiPluginLocalization.string("Monitor clipboard history locally on this device.", bundle: .module),
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
                title: LumiPluginLocalization.string("General", bundle: .module),
                spacing: 12
            ) {
                AppSettingsToggleRow(
                    LumiPluginLocalization.string("Enable Clipboard Monitoring", bundle: .module),
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
                    LumiPluginLocalization.string("History Size", bundle: .module),
                    systemImage: "clock.arrow.circlepath",
                    selection: $historySize
                ) {
                    Text(verbatim: LumiPluginLocalization.string("100", bundle: .module)).tag(100)
                    Text(verbatim: LumiPluginLocalization.string("500", bundle: .module)).tag(500)
                    Text(verbatim: LumiPluginLocalization.string("1000", bundle: .module)).tag(1000)
                    Text(LumiPluginLocalization.string("Unlimited", bundle: .module)).tag(Int.max)
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
                title: LumiPluginLocalization.string("Data", bundle: .module),
                spacing: 12
            ) {
                AppButton(
                    LumiPluginLocalization.string("Clear All History", bundle: .module),
                    style: .destructive,
                    fillsWidth: true
                ) {
                    Task {
                        await ClipboardStorage.shared.clear()
                    }
                }

                Text(LumiPluginLocalization.string("All data is stored locally in SwiftData database and will not be uploaded to any server.", bundle: .module))
                    .font(.appCaption)
                    .foregroundColor(theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
