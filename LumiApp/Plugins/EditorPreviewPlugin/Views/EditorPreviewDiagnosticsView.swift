#if canImport(LumiPreviewKit)
import AppKit
import SwiftUI

/// 编辑器预览诊断信息面板。
///
/// 在预览构建失败时展示错误日志，支持复制内容到粘贴板和文本选择。
struct EditorPreviewDiagnosticsView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    let diagnostics: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(String(localized: "Preview build failed", table: "EditorPreview"), systemImage: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)

                Spacer(minLength: 0)

                Button {
                    copyDiagnostics()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .help(String(localized: "Copy error details", table: "EditorPreview"))
                .accessibilityLabel(String(localized: "Copy error details", table: "EditorPreview"))
            }

            ScrollView {
                Text(diagnostics)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
    }

    private func copyDiagnostics() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics, forType: .string)
    }
}
#endif
