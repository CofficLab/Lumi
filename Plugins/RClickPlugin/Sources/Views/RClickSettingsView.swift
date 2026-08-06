import SwiftUI
import LumiUI

public struct RClickSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                    // MARK: - Finder Extension
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

                    // MARK: - General Actions
                    AppCard {
                        AppSettingsSection(title: LumiPluginLocalization.string("General Actions", bundle: .module)) {
                            ForEach(configManager.config.items) { item in
                                if item.type != .newFile {
                                    AppSettingsToggleRow(
                                        item.title,
                                        systemImage: item.type.iconName,
                                        isOn: Binding(
                                            get: { item.isEnabled },
                                            set: { _ in configManager.toggleItem(item) }
                                        )
                                    )
                                }
                            }
                        }
                    }

                    // MARK: - New File Menu
                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(LumiPluginLocalization.string("New File Menu", bundle: .module))
                                    .font(.appSectionTitle)
                                    .foregroundColor(theme.textPrimary)
                                Spacer()
                                AppButton(LumiPluginLocalization.string("Add Template", bundle: .module), style: .secondary, fillsWidth: true, action: { showingAddTemplateSheet = true })
                                .frame(width: 120)
                            }

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                                AppSettingsToggleRow(
                                    LumiPluginLocalization.string("Enable 'New File' Submenu", bundle: .module),
                                    systemImage: newFileItem.type.iconName,
                                    isOn: Binding(
                                        get: { newFileItem.isEnabled },
                                        set: { _ in configManager.toggleItem(newFileItem) }
                                    )
                                )
                            }

                            if configManager.config.items.first(where: { $0.type == .newFile })?.isEnabled == true {
                                List {
                                    ForEach(configManager.config.fileTemplates) { template in
                                        AppToggleRow(
                                            title: LocalizedStringKey(template.name),
                                            description: LocalizedStringKey(".\(template.extensionName)"),
                                            isOn: Binding(
                                                get: { template.isEnabled },
                                                set: { _ in configManager.toggleTemplate(template) }
                                            )
                                        )
                                    }
                                    .onDelete { indexSet in
                                        configManager.deleteTemplate(at: indexSet)
                                    }
                                }
                                .frame(minHeight: 100)
                            }
                        }
                    }

                    // MARK: - Reset
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
