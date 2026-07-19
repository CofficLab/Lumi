import SwiftUI
import LumiUI

public struct RClickSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    public var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text(LumiPluginLocalization.string("Preview", bundle: .module))
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
                                    Text(LumiPluginLocalization.string("Enable Finder Extension", bundle: .module))
                                        .font(.appTitle)
                                        .foregroundColor(theme.textPrimary)
                                    Text(LumiPluginLocalization.string("The right-click menu functionality requires the Finder extension to be enabled in System Settings.", bundle: .module))
                                        .font(.appCaption)
                                        .foregroundColor(theme.textSecondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: 8) {
                                AppButton(LumiPluginLocalization.string("Open System Settings", bundle: .module), style: .primary, fillsWidth: true, action: { openFinderExtensionSettings() })
                                .frame(width: 180)

                                Spacer()

                                Text(LumiPluginLocalization.string("System Settings → Privacy & Security → Extensions → Added Extensions", bundle: .module))
                                    .font(.appMicro)
                                    .foregroundColor(theme.textTertiary)
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LumiPluginLocalization.string("General Actions", bundle: .module))
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
                                Text(LumiPluginLocalization.string("New File Menu", bundle: .module))
                                    .font(.appTitle)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                AppButton(LumiPluginLocalization.string("Add Template", bundle: .module), style: .secondary, fillsWidth: true, action: { showingAddTemplateSheet = true })
                                .frame(width: 120)
                            }

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                                AppSettingsRow {
                                    HStack {
                                        Image(systemName: newFileItem.type.iconName)
                                            .frame(width: 20)
                                            .foregroundColor(theme.textSecondary)
                                        Text(LumiPluginLocalization.string("Enable 'New File' Submenu", bundle: .module))
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
                            Text(LumiPluginLocalization.string("Reset to Defaults", bundle: .module))
                                .font(.appBodyEmphasized)
                                .foregroundColor(theme.error)
                            Spacer()
                            AppButton(LumiPluginLocalization.string("Reset", bundle: .module), style: .destructive, fillsWidth: true, action: { configManager.resetToDefaults() })
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
