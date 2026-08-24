import SwiftUI
import LumiUI

public struct RClickSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    public var body: some View {
        PluginSettingsScaffold(
            title: LumiPluginLocalization.string("Right Click", bundle: .module),
            subtitle: LumiPluginLocalization.string("Customize Finder right-click menu actions", bundle: .module),
            showHeader: false
        ) {
            finderExtensionCard
            generalActionsCard
            newFileMenuCard
            resetCard
        }
        .sheet(isPresented: $showingAddTemplateSheet) {
            AddTemplateView(isPresented: $showingAddTemplateSheet) { name, ext, content in
                let template = NewFileTemplate(name: name, extensionName: ext, content: content)
                configManager.addTemplate(template)
            }
        }
    }

    // MARK: - Finder Extension

    private static var isMacOS15OrLater: Bool {
        if #available(macOS 15.0, *) { return true }
        return false
    }

    /// macOS 15+ 将扩展入口拆分为「扩展 → 文件提供程序」等子页面
    private static var extensionSettingsPath: String {
        if isMacOS15OrLater {
            return LumiPluginLocalization.string("Finder Extension Settings Path (macOS 15+)", bundle: .module)
        } else {
            return LumiPluginLocalization.string("Finder Extension Settings Path", bundle: .module)
        }
    }

    private var finderExtensionCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                GlassSectionHeader(
                    icon: "puzzlepiece.extension",
                    title: LumiPluginLocalization.string("Enable Finder Extension", bundle: .module),
                    subtitle: LumiPluginLocalization.string("The right-click menu functionality requires the Finder extension to be enabled in System Settings.", bundle: .module)
                )

                HStack(spacing: 8) {
                    AppButton(LumiPluginLocalization.string("Open System Settings", bundle: .module), style: .primary, fillsWidth: true, action: { openFinderExtensionSettings() })
                        .frame(width: 180)

                    Spacer()

                    Text(Self.extensionSettingsPath)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                }
            }
        }
    }

    // MARK: - General Actions

    private var generalActionsCard: some View {
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
    }

    // MARK: - New File Menu

    private var newFileMenuCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
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
                    ForEach(configManager.config.fileTemplates) { template in
                        AppSettingsRow {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.plus")
                                    .font(.appCallout)
                                    .foregroundColor(theme.primary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.name)
                                        .font(.appBody)
                                        .foregroundColor(theme.textPrimary)
                                    Text(".\(template.extensionName)")
                                        .font(.appCaption)
                                        .foregroundColor(theme.textSecondary)
                                }

                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { template.isEnabled },
                                    set: { _ in configManager.toggleTemplate(template) }
                                ))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)

                                AppIconButton(
                                    systemImage: "trash",
                                    tint: theme.error,
                                    action: { configManager.deleteTemplate(template) }
                                )
                                .help(LumiPluginLocalization.string("Delete Template", bundle: .module))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reset

    private var resetCard: some View {
        AppCard {
            AppSettingsRow {
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
    }

    // MARK: - Private

    private func openFinderExtensionSettings() {
        let urlString: String
        if Self.isMacOS15OrLater {
            // macOS 15+: 通用 → 登录项与扩展 → 扩展 → 文件提供程序
            urlString = "x-apple.systempreferences:com.apple.Extensions-List"
        } else {
            // macOS 13–14: 通用 → 登录项与扩展 → Finder 扩展
            urlString = "x-apple.systempreferences:com.apple.Extensions-List"
        }
        if let url = URL(string: urlString) {
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
