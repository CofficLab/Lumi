import LumiUI
import SwiftUI

public struct AddTemplateView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @Binding var isPresented: Bool
    public var onAdd: (String, String, String) -> Void

    @State private var name = ""
    @State private var ext = ""
    @State private var content = ""
    @State private var showNameError = false
    @State private var showExtensionError = false

    public var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Add New Template", table: "RClick"))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)

            Form {
                TextField(LocalizedStringKey(String(localized: "Name (e.g. Python Script)")), text: $name)
                    .onChange(of: name) { _, _ in showNameError = false }
                TextField(LocalizedStringKey(String(localized: "Extension (e.g. py)")), text: $ext)
                    .onChange(of: ext) { _, _ in showExtensionError = false }

                Section(header: Text(String(localized: "Default Content", table: "RClick"))) {
                    TextEditor(text: $content)
                        .frame(height: 100)
                        .font(.monospaced(.body)())
                        .appSurface(style: .listRow, cornerRadius: 8, borderColor: theme.appSubtleBorder)
                }
            }
            .formStyle(.grouped)

            if showNameError {
                AppErrorBanner(message: LocalizedStringKey(String(localized: "Template name cannot be empty or contain path separators", table: "RClick")))
            }

            if showExtensionError {
                AppErrorBanner(message: LocalizedStringKey(String(localized: "Extension can only contain letters, numbers, hyphen, or underscore", table: "RClick")))
            }

            HStack {
                AppButton(localized: "Cancel", table: "Localizable", style: .ghost, fillsWidth: true, action: { isPresented = false })
                Spacer()
                AppButton(localized: "Add", table: "Localizable", style: .primary, fillsWidth: true, action: {
                    guard let normalizedName = NewFileTemplate.normalizedName(name) else {
                        showNameError = true
                        return
                    }

                    guard let normalizedExtension = NewFileTemplate.normalizedExtension(ext) else {
                        showExtensionError = true
                        return
                    }

                    onAdd(normalizedName, normalizedExtension, content)
                    isPresented = false
                })
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .padding()
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView()
        .withDebugBar()
}
