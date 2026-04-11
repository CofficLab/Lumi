import SwiftUI
import MagicKit

/// 编辑器底部状态栏视图
/// 显示光标位置、行数、语言等信息
struct LumiEditorStatusBarView: View {
    
    @ObservedObject var state: LumiEditorState
    
    var body: some View {
        HStack(spacing: 12) {
            // 光标位置
            Text("Ln \(state.cursorLine), Col \(state.cursorColumn)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
            
            // 总行数
            if state.totalLines > 0 {
                Text("\(state.totalLines) lines")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(AppUI.Color.semantic.textTertiary)
            }
        }
        .padding(.horizontal, 4)
    }
}
