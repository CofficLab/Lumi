import AppKit
import SwiftUI
import LumiUI

public struct RClickSettingsView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @ObservedObject private var viewModel: RClickSettingsViewModel
    @State private var showingAddTemplateSheet = false

    init(viewModel: RClickSettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        PluginSettingsScaffold(
            title: pluginLocalization.string("Right Click"),
            subtitle: pluginLocalization.string("Customize Finder right-click menu actions"),
            showHeader: false
        ) {
            finderExtensionCard
            generalActionsCard
            newFileMenuCard
            resetCard
        }
        .sheet(isPresented: $showingAddTemplateSheet) {
            AddTemplateView(isPresented: $showingAddTemplateSheet) { name, ext, content in
                viewModel.addTemplate(name: name, extensionName: ext, content: content)
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
            return pluginLocalization.string("Finder Extension Settings Path (macOS 15+)")
        } else {
            return pluginLocalization.string("Finder Extension Settings Path")
        }
    }

    private var finderExtensionCard: some View {
        AppSettingSection(title: nil, titleAlignment: .leading) {
            VStack(alignment: .leading, spacing: 16) {
                GlassSectionHeader(
                    icon: "puzzlepiece.extension",
                    title: pluginLocalization.string("Enable Finder Extension"),
                    subtitle: pluginLocalization.string("The right-click menu functionality requires the Finder extension to be enabled in System Settings.")
                )

                HStack(spacing: 8) {
                    AppButton(pluginLocalization.string("Open System Settings"), style: .primary, fillsWidth: true, action: { viewModel.openFinderExtensionSettings() })
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

    /// 「通用动作」分组里展示的菜单项（排除「新建文件」子菜单）。
    private var generalActionItems: [RClickMenuItem] {
        viewModel.config.items.filter { $0.type != .newFile }
    }

    private var generalActionsCard: some View {
        AppSettingSection(
            title: pluginLocalization.string("General Actions"),
            titleAlignment: .leading
        ) {
            VStack(spacing: 0) {
                ForEach(Array(generalActionItems.enumerated()), id: \.element.id) { index, item in
                    AppSettingToggleRow(
                        item.title,
                        icon: item.type.iconName,
                        isOn: Binding(
                            get: { item.isEnabled },
                            set: { _ in viewModel.toggleItem(item) }
                        )
                    )

                    if index < generalActionItems.count - 1 {
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    // MARK: - New File Menu

    private var newFileMenuCard: some View {
        AppSettingSection(title: nil, titleAlignment: .leading) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(pluginLocalization.string("New File Menu"))
                        .font(.appSectionTitle)
                        .foregroundColor(theme.textPrimary)
                    Spacer()
                    AppButton(pluginLocalization.string("Add Template"), style: .secondary, fillsWidth: true, action: { showingAddTemplateSheet = true })
                        .frame(width: 120)
                }

                VStack(spacing: 0) {
                    if let newFileItem = viewModel.newFileItem {
                        AppSettingToggleRow(
                            pluginLocalization.string("Enable 'New File' Submenu"),
                            icon: newFileItem.type.iconName,
                            isOn: Binding(
                                get: { newFileItem.isEnabled },
                                set: { _ in viewModel.toggleItem(newFileItem) }
                            )
                        )
                    }

                    if viewModel.newFileItem?.isEnabled == true {
                        ForEach(Array(viewModel.config.fileTemplates.enumerated()), id: \.element.id) { index, template in
                            if index == 0 {
                                Divider()
                                    .padding(.vertical, 8)
                            }

                            AppSettingRow(
                                title: template.name,
                                description: ".\(template.extensionName)",
                                icon: "doc.badge.plus"
                            ) {
                                HStack(spacing: 12) {
                                    Toggle("", isOn: Binding(
                                        get: { template.isEnabled },
                                        set: { _ in viewModel.toggleTemplate(template) }
                                    ))
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                                    .controlSize(.small)

                                    AppIconButton(
                                        systemImage: "trash",
                                        tint: theme.error,
                                        action: { viewModel.deleteTemplate(template) }
                                    )
                                    .help(pluginLocalization.string("Delete Template"))
                                }
                            }

                            if index < viewModel.config.fileTemplates.count - 1 {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reset

    private var resetCard: some View {
        AppSettingSection(title: nil, titleAlignment: .leading) {
            AppSettingRow(
                title: pluginLocalization.string("Reset to Defaults"),
                titleColor: theme.error
            ) {
                AppButton(pluginLocalization.string("Reset"), style: .destructive, fillsWidth: true, action: { viewModel.resetToDefaults() })
                    .frame(width: 100)
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
