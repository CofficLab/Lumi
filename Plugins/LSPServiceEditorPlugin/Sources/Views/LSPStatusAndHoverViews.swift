import LanguageServerProtocol
import LumiUI
import SwiftUI

/// LSP 诊断状态栏项目。
///
/// 展示当前文件诊断中的错误和警告数量。该视图通过 `DiagnosticsManager` 观察
/// `LSPService.currentDiagnostics`，只负责状态栏展示，不负责诊断请求或发布。
public struct LSPDiagnosticStatusBarItem: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    
    @StateObject private var diagnosticsManager = DiagnosticsManager()
    
    public var body: some View {
        HStack(spacing: 12) {
            if diagnosticsManager.errorCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(theme.error)
                    Text("\(diagnosticsManager.errorCount)")
                        .font(.appMicroEmphasized)
                }
            }
            
            if diagnosticsManager.warningCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(theme.warning)
                    Text("\(diagnosticsManager.warningCount)")
                        .font(.appMicroEmphasized)
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
public struct LSPHoverTooltip: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme
    
    public let content: String
    
    public var body: some View {
        Text(content)
            .font(.appMonoCaption)
            .foregroundColor(theme.textPrimary)
            .padding(8)
            .frame(maxWidth: 400, alignment: .leading)
            .appSurface(style: .popover, cornerRadius: 6, borderColor: theme.divider)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}
