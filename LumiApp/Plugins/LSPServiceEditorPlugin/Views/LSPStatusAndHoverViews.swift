import SwiftUI
import LanguageServerProtocol

/// LSP 诊断状态栏项目。
///
/// 展示当前文件诊断中的错误和警告数量。该视图通过 `DiagnosticsManager` 观察
/// `LSPService.currentDiagnostics`，只负责状态栏展示，不负责诊断请求或发布。
struct LSPDiagnosticStatusBarItem: View {
    
    @StateObject private var diagnosticsManager = DiagnosticsManager()
    
    var body: some View {
        HStack(spacing: 12) {
            if diagnosticsManager.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(diagnosticsManager.errorCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            
            if diagnosticsManager.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(diagnosticsManager.warningCount)")
                        .font(.system(size: 11, weight: .medium))
                }
            }
        }
        .opacity(diagnosticsManager.errorCount > 0 || diagnosticsManager.warningCount > 0 ? 1 : 0)
    }
}

/// LSP Hover 简易提示浮层。
///
/// 用于展示一段纯文本 hover 内容。当前编辑器主流程更多使用 Markdown hover popover，
/// 该视图保留为 LSP 服务插件内的轻量展示组件。
struct LSPHoverTooltip: View {
    
    let content: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Text(content)
            .font(.system(size: 12, design: .monospaced))
            .padding(8)
            .frame(maxWidth: 400, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color(nsColor: .controlBackgroundColor) : Color.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
            )
    }
}
