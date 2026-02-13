import SwiftUI

struct AddTemplateView: View {
    @Binding var isPresented: Bool
    var onAdd: (String, String, String) -> Void

    @State private var name = ""
    @State private var ext = ""
    @State private var content = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add New Template")
                .font(.headline)
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Form {
                TextField(LocalizedStringKey(String(localized: "Name (e.g. Python Script)")), text: $name)
                TextField(LocalizedStringKey(String(localized: "Extension (e.g. py)")), text: $ext)

                Section(header: Text("Default Content")) {
                    TextEditor(text: $content)
                        .frame(height: 100)
                        .font(.monospaced(.body)())
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DesignTokens.Color.semantic.textTertiary.opacity(0.3)))
                }
            }
            .formStyle(.grouped)

            HStack {
                GlassButton(title: LocalizedStringKey(String(localized: "Cancel")), style: .ghost) {
                    isPresented = false
                }
                Spacer()
                GlassButton(title: LocalizedStringKey(String(localized: "Add")), style: .primary) {
                    onAdd(name, ext, content)
                    isPresented = false
                }
                .disabled(name.isEmpty || ext.isEmpty)
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
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
