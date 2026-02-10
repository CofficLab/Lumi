import SwiftUI

struct RClickSettingsView: View {
    @StateObject private var configManager = RClickConfigManager.shared
    @State private var showingAddTemplateSheet = false

    var body: some View {
        Form {
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

            Section {
                Button("Reset to Defaults") {
                    configManager.resetToDefaults()
                }
                .foregroundColor(.red)

                HStack {
                    Image(systemName: "info.circle")
                    Text("Changes require the Finder extension to be enabled in System Settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showingAddTemplateSheet) {
            AddTemplateView(isPresented: $showingAddTemplateSheet) { name, ext, content in
                let template = NewFileTemplate(name: name, extensionName: ext, content: content)
                configManager.addTemplate(template)
            }
        }
    }
}

struct AddTemplateView: View {
    @Binding var isPresented: Bool
    var onAdd: (String, String, String) -> Void

    @State private var name = ""
    @State private var ext = ""
    @State private var content = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Template").font(.headline)

            Form {
                TextField("Name (e.g. Python Script)", text: $name)
                TextField("Extension (e.g. py)", text: $ext)

                Section(header: Text("Default Content")) {
                    TextEditor(text: $content)
                        .frame(height: 100)
                        .font(.monospaced(.body)())
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { isPresented = false }
                Spacer()
                Button("Add") {
                    onAdd(name, ext, content)
                    isPresented = false
                }
                .disabled(name.isEmpty || ext.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .padding()
    }
}
