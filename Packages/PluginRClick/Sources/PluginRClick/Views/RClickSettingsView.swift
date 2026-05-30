import SwiftUI
import LumiUI

public struct RClickSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text(String(localized: "Preview", table: "RClick"))
                    .font(.appBodyEmphasized)
                    .foregroundColor(theme.textSecondary)

                RClickPreviewView(config: configManager.config)
                    .shadow(color: Color.black.opacity(0.09), radius: 12, x: 0, y: 4)
            }
            .padding()

            .frame(width: 260)

            settingsDivider

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppCard {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.appTitle)
                                    .foregroundColor(theme.primary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "Enable Finder Extension", table: "RClick"))
                                        .font(.appTitle)
                                        .foregroundColor(theme.textPrimary)
                                    Text(String(localized: "The right-click menu functionality requires the Finder extension to be enabled in System Settings.", table: "RClick"))
                                        .font(.appCaption)
                                        .foregroundColor(theme.textSecondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: 8) {
                                AppButton(localized: "Open System Settings", table: "Localizable", style: .primary, fillsWidth: true, action: { openFinderExtensionSettings() })
                                .frame(width: 180)

                                Spacer()

                                Text(String(localized: "System Settings → Privacy & Security → Extensions → Added Extensions", table: "RClick"))
                                    .font(.appMicro)
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "General Actions", table: "RClick"))
                                .font(.appTitle)
                                .foregroundColor(theme.textPrimary)

                            VStack(spacing: 4) {
                                ForEach(configManager.config.items) { item in
                                    if item.type != .newFile {
                                        AppSettingsRow {
                                            HStack {
                                                Image(systemName: item.type.iconName)
                                                    .frame(width: 20)
                                                    .foregroundColor(theme.textSecondary)
                                                Text(item.title)
                                                    .font(.appBody)
                                                    .foregroundColor(theme.textPrimary)
                                                Spacer()
                                                Toggle("", isOn: Binding(
                                                    get: { item.isEnabled },
                                                    set: { _ in configManager.toggleItem(item) }
                                                ))
                                                .labelsHidden()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(String(localized: "New File Menu", table: "RClick"))
                                    .font(.appTitle)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                AppButton(localized: "Add Template", table: "Localizable", style: .secondary, fillsWidth: true, action: { showingAddTemplateSheet = true })
                                .frame(width: 120)
                            }

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                                AppSettingsRow {
                                    HStack {
                                        Image(systemName: newFileItem.type.iconName)
                                            .frame(width: 20)
                                            .foregroundColor(theme.textSecondary)
                                        Text(String(localized: "Enable 'New File' Submenu", table: "RClick"))
                                            .font(.appBody)
                                            .foregroundColor(theme.textPrimary)
                                        Spacer()
                                        Toggle("", isOn: Binding(
                                            get: { newFileItem.isEnabled },
                                            set: { _ in configManager.toggleItem(newFileItem) }
                                        ))
                                        .labelsHidden()
                                    }
                                }
                            }

                            if configManager.config.items.first(where: { $0.type == .newFile })?.isEnabled == true {
                                List {
                                    ForEach(configManager.config.fileTemplates) { template in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(template.name)
                                                    .font(.appBody)
                                                    .foregroundColor(theme.textPrimary)
                                                Text(".\(template.extensionName)")
                                                    .font(.appMicro)
                                                    .foregroundColor(theme.textTertiary)
                                            }
                                            Spacer()
                                            Toggle("", isOn: Binding(
                                                get: { template.isEnabled },
                                                set: { _ in configManager.toggleTemplate(template) }
                                            ))
                                            .labelsHidden()
                                        }
                                    }
                                    .onDelete { indexSet in
                                        configManager.deleteTemplate(at: indexSet)
                                    }
                                }
                                .frame(minHeight: 100)
                            }
                        }
                    }

                    AppCard {
                        HStack {
                            Text(String(localized: "Reset to Defaults", table: "RClick"))
                                .font(.appBodyEmphasized)
                                .foregroundColor(theme.error)
                            Spacer()
                            AppButton(localized: "Reset", table: "Localizable", style: .destructive, fillsWidth: true, action: { configManager.resetToDefaults() })
                            .frame(width: 100)
                        }
                    }
                }
                .padding(16)
            }
            .sheet(isPresented: $showingAddTemplateSheet) {
                AddTemplateView(isPresented: $showingAddTemplateSheet) { name, ext, content in
                    let template = NewFileTemplate(name: name, extensionName: ext, content: content)
                    configManager.addTemplate(template)
                }
            }
        }
    }

    private var settingsDivider: some View {
        Rectangle()
            .fill(theme.appDivider)
            .frame(height: 1)
    }

    // MARK: - Private

    private func openFinderExtensionSettings() {
        // macOS 13+ use new System Settings URL
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
