import LumiUI
import SwiftUI

/// Code Action 灯泡指示器。
///
/// 用于在编辑器中提示当前位置或当前行存在可用的快速修复/代码动作。
/// 该视图只负责显示灯泡图标和处理点击事件，不负责计算动作是否可用；
/// `hasActions` 由上层根据 `CodeActionProvider.actions` 或相关状态传入。
struct LightbulbIndicator: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let hasActions: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "lightbulb")
                .font(.appMicroEmphasized)
                .foregroundColor(hasActions ? theme.warning : theme.textSecondary)
                .opacity(hasActions ? 1 : 0.3)
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}
