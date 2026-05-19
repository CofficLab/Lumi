import SwiftUI
import LumiUI

struct RClickSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 20) {
                Text(String(localized: "Preview", table: "RClick"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                RClickPreviewView(config: configManager.config)
                    .shadow(color: Color.black.opacity(0.09), radius: 12, x: 0, y: 4)
            }
            .padding()

            .frame(width: 260)

            GlassDivider()
                .frame(width: 1, height: 380)
                .rotationEffect(.degrees(90))

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppCard {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "puzzlepiece.extension")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(hex: "7C6FFF"))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(String(localized: "Enable Finder Extension", table: "RClick"))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                                    Text(String(localized: "The right-click menu functionality requires the Finder extension to be enabled in System Settings.", table: "RClick"))
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                }

                                Spacer()
                            }

                            HStack(spacing: 8) {
                                GlassButton(title: LocalizedStringKey(String(localized: "Open System Settings")), style: .primary) {
                                    openFinderExtensionSettings()
                                }
                                .frame(width: 180)

                                Spacer()

                                Text(String(localized: "System Settings → Privacy & Security → Extensions → Added Extensions", table: "RClick"))
                                    .font(.system(size: 11, weight: .regular))
                                    .foregroundColor(Color(hex: "98989E"))
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "General Actions", table: "RClick"))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                            VStack(spacing: 4) {
                                ForEach(configManager.config.items) { item in
                                    if item.type != .newFile {
                                        GlassRow {
                                            HStack {
                                                Image(systemName: item.type.iconName)
                                                    .frame(width: 20)
                                                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                                Text(item.title)
                                                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                                Spacer()
                                GlassButton(title: LocalizedStringKey(String(localized: "Add Template")), style: .secondary) {
                                    showingAddTemplateSheet = true
                                }
                                .frame(width: 120)
                            }

                            if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                                GlassRow {
                                    HStack {
                                        Image(systemName: newFileItem.type.iconName)
                                            .frame(width: 20)
                                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                        Text(String(localized: "Enable 'New File' Submenu", table: "RClick"))
                                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
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
                                                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                                                Text(".\(template.extensionName)")
                                                    .font(.system(size: 11, weight: .regular))
                                                    .foregroundColor(Color(hex: "98989E"))
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
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color.adaptive(light: "FF3B30", dark: "FF453A"))
                            Spacer()
                            GlassButton(title: LocalizedStringKey(String(localized: "Reset")), style: .danger) {
                                configManager.resetToDefaults()
                            }
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
