import LumiUI
import SwiftUI

struct AddTemplateView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @Binding var isPresented: Bool
    var onAdd: (String, String, String) -> Void

    @State private var name = ""
    @State private var ext = ""
    @State private var content = ""

    var body: some View {
        VStack(spacing: 20) {
            Text(String(localized: "Add New Template", table: "RClick"))
                .font(.appBodyEmphasized)
                .foregroundColor(theme.textPrimary)

            Form {
                TextField(LocalizedStringKey(String(localized: "Name (e.g. Python Script)")), text: $name)
                TextField(LocalizedStringKey(String(localized: "Extension (e.g. py)")), text: $ext)

                Section(header: Text(String(localized: "Default Content", table: "RClick"))) {
                    TextEditor(text: $content)
                        .frame(height: 100)
                        .font(.monospaced(.body)())
                        .appSurface(style: .listRow, cornerRadius: 8, borderColor: theme.appSubtleBorder)
                }
            }
            .formStyle(.grouped)

            HStack {
                AppButton(localized: "Cancel", table: "Localizable", style: .ghost, fillsWidth: true, action: { isPresented = false })
                Spacer()
                AppButton(localized: "Add", table: "Localizable", style: .primary, fillsWidth: true, action: {
                    onAdd(name, ext, content)
                    isPresented = false
                })
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
        .inRootView()
        .withDebugBar()
}
