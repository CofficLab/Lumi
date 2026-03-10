import SwiftUI

// MARK: - Collapse Button

/// 折叠按钮组件
/// 用于在助手消息 Header 中显示折叠/展开操作
struct CollapseButton: View {
    /// 点击回调
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
                Text("折叠")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary.opacity(0.8))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.Color.semantic.textSecondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .help("折叠消息")
    }
}
