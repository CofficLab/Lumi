import SwiftUI

struct RClickSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 20) {
                Text("Preview")
                    .font(AppUI.Typography.bodyEmphasized)
                    .foregroundColor(AppUI.Color.semantic.textSecondary)

                RClickPreviewView(config: configManager.config)
                    .shadow(color: AppUI.Shadow.subtle.opacity(0.6), radius: AppUI.Shadow.subtleRadius, x: 0, y: AppUI.Shadow.subtleOffset)
            }
            .padding()

            .frame(width: 260)

            GlassDivider()
                .frame(width: 1, height: 380)
                .rotationEffect(.degrees(90))

            ScrollView {
                VStack(alignment: .leading, spacing: AppUI.Spacing.md) {
                    GlassCard {
                        VStack(spacing: AppUI.Spacing.sm) {
                            HStack(spacing: AppUI.Spacing.sm) {
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.system(size: 28))
                                    .foregroundColor(AppUI.Color.semantic.primary)

                                VStack(alignment: .leading, spacing: AppUI.Spacing.xs) {
                                    Text("Enable Finder Extension")
                                        .font(AppUI.Typography.title3)
                                        .foregroundColor(AppUI.Color.semantic.textPrimary)
                                    Text("The right-click menu functionality requires the Finder extension to be enabled in System Settings.")
                                        .font(AppUI.Typography.caption1)
                                        .foregroundColor(AppUI.Color.semantic.textSecondary)
                                }

                                Spacer()
                            }

                            HStack(spacing: AppUI.Spacing.sm) {
                                GlassButton(title: LocalizedStringKey(String(localized: "Open System Settings")), style: .primary) {
                                    openFinderExtensionSettings()
                                }
                                .frame(width: 180)

                                Spacer()

                                Text("System Settings → Privacy & Security → Extensions → Added Extensions")
                                    .font(AppUI.Typography.caption2)
                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                            Text("General Actions")
                                .font(AppUI.Typography.title3)
                                .foregroundColor(AppUI.Color.semantic.textPrimary)

                            VStack(spacing: AppUI.Spacing.xs) {
                                ForEach(configManager.config.items) { item in
                                    if item.type != .newFile {
                                        GlassRow {
                                            HStack {
                                                Image(systemName: item.type.iconName)
                                                    .frame(width: 20)
                                                    .foregroundColor(AppUI.Color.semantic.textSecondary)
                                                Text(item.title)
                                                    .foregroundColor(AppUI.Color.semantic.textPrimary)
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

                    GlassCard {
                        VStack(alignment: .leading, spacing: AppUI.Spacing.sm) {
                            Text("New File Menu")
                                .font(AppUI.Typography.title3)
                                .foregroundColor(AppUI.Color.semantic.textPrimary)

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                                GlassRow {
                                    HStack {
                                        Image(systemName: newFileItem.type.iconName)
                                            .frame(width: 20)
                                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                                        Text("Enable 'New File' Submenu")
                                            .foregroundColor(AppUI.Color.semantic.textPrimary)
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
                                                    .foregroundColor(AppUI.Color.semantic.textPrimary)
                                                Text(".\(template.extensionName)")
                                                    .font(AppUI.Typography.caption2)
                                                    .foregroundColor(AppUI.Color.semantic.textTertiary)
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

                                GlassButton(title: LocalizedStringKey(String(localized: "Add Template")), style: .secondary) {
                                    showingAddTemplateSheet = true
                                }
                                .frame(width: 140)
                            }
                        }
                    }

                    GlassCard {
                        HStack {
                            Text("Reset to Defaults")
                                .font(AppUI.Typography.bodyEmphasized)
                                .foregroundColor(AppUI.Color.adaptive.error(for: colorScheme))
                            Spacer()
                            GlassButton(title: LocalizedStringKey(String(localized: "Reset")), style: .danger) {
                                configManager.resetToDefaults()
                            }
                            .frame(width: 100)
                        }
                    }
                }
                .padding(AppUI.Spacing.md)
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
        .inRootView()
        .withDebugBar()
}
