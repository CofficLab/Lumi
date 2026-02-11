import SwiftUI

struct RClickSettingsView: View {
    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    var body: some View {
        HStack(spacing: 0) {
            // Preview Section
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    RClickPreviewView(config: configManager.config)
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 6)
                }
                .padding()
            }
            .frame(width: 260)

            Divider()

            // Settings Form
            Form {
                // MARK: - Finder Extension Setup Guide

                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.extension")
                                .font(.system(size: 28))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Enable Finder Extension")
                                    .font(.headline)
                                Text("The right-click menu functionality requires the Finder extension to be enabled in System Settings.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        HStack(spacing: 12) {
                            Button {
                                openFinderExtensionSettings()
                            } label: {
                                Label("Open System Settings", systemImage: "gear")
                            }
                            .buttonStyle(.borderedProminent)

                            Spacer()

                            Text("System Settings → Privacy & Security → Extensions → Added Extensions")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - General Actions

                Section(header: Text("General Actions")) {
                    ForEach(configManager.config.items) { item in
                        if item.type != .newFile {
                            HStack {
                                Image(systemName: item.type.iconName)
                                    .frame(width: 20)
                                Text(item.title)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { _ in configManager.toggleItem(item) }
                                ))
                            }
                        }
                    }
                }

                // MARK: - New File Menu

                Section(header: Text("New File Menu")) {
                    if let newFileItem = configManager.config.items.first(where: { $0.type == .newFile }) {
                        HStack {
                            Image(systemName: newFileItem.type.iconName)
                                .frame(width: 20)
                            Text("Enable 'New File' Submenu")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { newFileItem.isEnabled },
                                set: { _ in configManager.toggleItem(newFileItem) }
                            ))
                        }
                    }

                    if configManager.config.items.first(where: { $0.type == .newFile })?.isEnabled == true {
                        List {
                            ForEach(configManager.config.fileTemplates) { template in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(template.name)
                                        Text(".\(template.extensionName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Toggle("", isOn: Binding(
                                        get: { template.isEnabled },
                                        set: { _ in configManager.toggleTemplate(template) }
                                    ))
                                }
                            }
                            .onDelete { indexSet in
                                configManager.deleteTemplate(at: indexSet)
                            }
                        }
                        .frame(minHeight: 100)

                        Button(action: { showingAddTemplateSheet = true }) {
                            Label("Add Template", systemImage: "plus")
                        }
                    }
                }

                // MARK: - Reset

                Section {
                    Button("Reset to Defaults") {
                        configManager.resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .formStyle(.grouped)
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
