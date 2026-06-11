import LumiUI
import SwiftUI
import LumiCoreKit

// MARK: - Collapse Button

/// 折叠按钮组件
/// 用于在助手消息 Header 中显示折叠/展开操作
public struct CollapseButton: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    /// 点击回调
    public let action: () -> Void

    public var body: some View {
        AppIconButton(
            systemImage: "chevron.up",
            label: LumiPluginLocalization.string("Collapse", bundle: .module),
            tint: theme.textSecondary.opacity(0.8),
            size: .compact,
            action: action
        )
        .help(LumiPluginLocalization.string("Collapse Message", bundle: .module))
    }
}
