import SwiftUI

/// SidebarView 中的阻塞原因提示卡片。
///
/// 仅当 Goal 处于 `.blocked` 且 `blockedReason` 非空时展示,
/// 文案使用本地化的 "⚠️ %@" 模板。组件本身不做条件判断,
/// 由 `SidebarView` 通过 `@ViewBuilder` 按需渲染。
///
/// 卡片样式与 `TaskRowView` 保持一致(橙色半透明底 + 圆角描边),
/// 高度按 2 行 `caption2` 固定,与 `SidebarView.blockedReasonCardHeight` 对齐。
struct SidebarBlockedReason: View {
    let reason: String

    var body: some View {
        Text(String(format: pluginLocalization.string("⚠️ %@"), reason))
            .font(.caption2)
            .foregroundStyle(.orange)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: SidebarView.blockedReasonCardHeight)
            .background(Color.orange.opacity(0.075))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.orange.opacity(0.12), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 12)
            .accessibilityIdentifier(GoalAccessibility.blockedReason)
    }
}