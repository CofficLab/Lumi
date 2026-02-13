import SwiftUI

struct RClickSettingsView: View {
    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 20) {
                Text("Preview")
                    .font(.headline)
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                RClickPreviewView(config: configManager.config)
                    .shadow(color: DesignTokens.Shadow.subtle.opacity(0.6), radius: DesignTokens.Shadow.subtleRadius, x: 0, y: DesignTokens.Shadow.subtleOffset)
            }
            .padding()

            .frame(width: 260)

            GlassDivider()
                .frame(width: 1, height: 380)
                .rotationEffect(.degrees(90))

            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    MystiqueGlassCard {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            HStack(spacing: DesignTokens.Spacing.sm) {
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.system(size: 28))
                                    .foregroundColor(DesignTokens.Color.semantic.primary)

                                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                                    Text("Enable Finder Extension")
                                        .font(DesignTokens.Typography.title3)
                                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                    Text("The right-click menu functionality requires the Finder extension to be enabled in System Settings.")
                                        .font(DesignTokens.Typography.caption1)
                                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: DesignTokens.Spacing.sm) {
                                GlassButton(title: "Open System Settings", style: .primary) {
                                    openFinderExtensionSettings()
                                }
                                .frame(width: 180)

                                Spacer()

                                Text("System Settings → Privacy & Security → Extensions → Added Extensions")
                                    .font(DesignTokens.Typography.caption2)
                                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                            }
                        }
                    }

                    MystiqueGlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("General Actions")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            VStack(spacing: DesignTokens.Spacing.xs) {
                                ForEach(configManager.config.items) { item in
                                    if item.type != .newFile {
                                        GlassRow {
                                            HStack {
                                                Image(systemName: item.type.iconName)
                                                    .frame(width: 20)
                                                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                                Text(item.title)
                                                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
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

                    MystiqueGlassCard {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("New File Menu")
                                .font(DesignTokens.Typography.title3)
                                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                                GlassRow {
                                    HStack {
                                        Image(systemName: newFileItem.type.iconName)
                                            .frame(width: 20)
                                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                                        Text("Enable 'New File' Submenu")
                                            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
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
                                                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                                                Text(".\(template.extensionName)")
                                                    .font(DesignTokens.Typography.caption2)
                                                    .foregroundColor(DesignTokens.Color.semantic.textTertiary)
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

                                GlassButton(title: "Add Template", style: .secondary) {
                                    showingAddTemplateSheet = true
                                }
                                .frame(width: 140)
                            }
                        }
                    }

                    MystiqueGlassCard {
                        HStack {
                            Text("Reset to Defaults")
                                .font(DesignTokens.Typography.bodyEmphasized)
                                .foregroundColor(DesignTokens.Color.semantic.error)
                            Spacer()
                            GlassButton(title: "Reset", style: .danger) {
                                configManager.resetToDefaults()
                            }
                            .frame(width: 100)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .sheet(isPresented: $showingAddTemplateSheet) {
                AddTemplateView(isPresented: $showingAddTemplateSheet) { name, ext, content in
                    let template = NewFileTemplate(name: name, extensionName: ext, content: content)
                    configManager.addTemplate(template)
                }
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
        .withNavigation(RClickPlugin.id)
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
