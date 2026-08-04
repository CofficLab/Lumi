import LumiUI
import SwiftUI

/// 在消息行的右上角显示当前 `LumiMessageRendererItem.id` 的小徽章。
///
/// 由 `MessageRowView` 在分发到具体 renderer 之前统一叠加,
/// 避免在每个 renderer 视图内部重复添加 —— 任何新增的 renderer
/// (无论由哪个插件贡献) 都会自动获得对应 `id` 的徽章。
struct MessageRendererIdBadge: View {
    @LumiTheme private var theme

    /// renderer id,来自 `LumiMessageRendererItem.id`。
    let id: String

    var body: some View {
        Text(id)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                theme.textSecondary.opacity(0.10),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(theme.textSecondary.opacity(0.18), lineWidth: 0.5)
            )
            .fixedSize()
    }
}

extension View {
    /// 在视图右上角叠加当前 renderer 的 `id` 徽章。
    func messageRendererIdBadge(_ id: String) -> some View {
        overlay(alignment: .topTrailing) {
            MessageRendererIdBadge(id: id)
        }
    }
}