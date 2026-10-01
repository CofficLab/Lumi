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
            GlassSectionHeader(
                icon: "doc.badge.plus",
                title: pluginLocalization.string("Add New Template")
            )

            VStack(spacing: 12) {
                GlassTextField(
                    title: pluginLocalization.string("Name (e.g. Python Script)"),
                    text: $name
                )
                .onChange(of: name) { _, _ in showNameError = false }

                GlassTextField(
                    title: pluginLocalization.string("Extension (e.g. py)"),
                    text: $ext
                )
                .onChange(of: ext) { _, _ in showExtensionError = false }

                VStack(alignment: .leading, spacing: 4) {
                    Text(pluginLocalization.string("Default Content"))
                        .font(.appCaption)
                        .foregroundColor(theme.textTertiary)
                    TextEditor(text: $content)
                        .font(.monospaced(.body)())
                        .scrollContentBackground(.hidden)
                        .frame(height: 100)
                        .appSurface(style: .listRow, cornerRadius: 8, borderColor: theme.appSubtleBorder)
                }
            }

            if showNameError {
                AppErrorBanner(message: LocalizedStringKey(pluginLocalization.string("Template name cannot be empty or contain path separators")))
            }

            if showExtensionError {
                AppErrorBanner(message: LocalizedStringKey(pluginLocalization.string("Extension can only contain letters, numbers, hyphen, or underscore")))
            }

            HStack {
                AppButton(pluginLocalization.string("Cancel"), style: .ghost, fillsWidth: true, action: { isPresented = false })
                Spacer()
                AppButton(pluginLocalization.string("Add"), style: .primary, fillsWidth: true, action: {
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
