import LumiUI
import SwiftUI

public struct ClipboardSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var historySize: Int = ClipboardSettings.defaultHistorySize
    @State private var isMonitoringEnabled: Bool = true

    /// 监控开关变化时通知插件运行时立即启停采集。
    private let onMonitoringChange: ((Bool) -> Void)?

    public init(onMonitoringChange: ((Bool) -> Void)? = nil) {
        self.onMonitoringChange = onMonitoringChange
    }

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
            isMonitoringEnabled = ClipboardSettings.isMonitoringEnabled
            historySize = ClipboardSettings.historyLimit
        }
    }

    private var generalSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("General"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                AppSettingToggleRow(
                    pluginLocalization.string("Enable Clipboard Monitoring"),
                    icon: "doc.on.clipboard",
                    isOn: $isMonitoringEnabled
                )
                .onChange(of: isMonitoringEnabled) { newValue in
                    ClipboardSettings.setMonitoringEnabled(newValue)
                    onMonitoringChange?(newValue)
                }

                Divider()
                    .padding(.vertical, 8)

                AppSettingRow(
                    title: pluginLocalization.string("History Size"),
                    icon: "clock.arrow.circlepath"
                ) {
                    Picker("", selection: $historySize) {
                        Text(verbatim: pluginLocalization.string("100")).tag(100)
                        Text(verbatim: pluginLocalization.string("500")).tag(500)
                        Text(verbatim: pluginLocalization.string("1000")).tag(1000)
                        Text(pluginLocalization.string("Unlimited")).tag(Int.max)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 120)
                }
                .onChange(of: historySize) { newValue in
                    ClipboardSettings.setHistoryLimit(newValue)
                }
            }
        }
    }

    private var dataSection: some View {
        AppSettingSection(
            title: pluginLocalization.string("Data"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 8) {
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
