import SwiftUI

/// SidebarView 中的阻塞原因提示行。
///
/// 仅当 Goal 处于 `.blocked` 且 `blockedReason` 非空时展示,
/// 文案使用本地化的 "⚠️ %@" 模板。组件本身不做条件判断,
/// 由 `SidebarView` 通过 `@ViewBuilder` 按需渲染。
struct SidebarBlockedReason: View {
    let reason: String

    var body: some View {
        Text(String(format: LumiPluginLocalization.string("⚠️ %@", bundle: .module), reason))
            .font(.caption2)
            .foregroundStyle(.orange)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.top, 4)
    }
}