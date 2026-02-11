import SwiftUI

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

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
