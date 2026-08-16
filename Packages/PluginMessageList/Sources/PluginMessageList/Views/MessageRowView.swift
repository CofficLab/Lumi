import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// Renders a single message using the injected message renderer,
/// or a fallback if no renderer is available.
///
/// `verbosity` 由 `MessageListView` 计算并显式传入，再由 `MessageRendererItem.render`
/// 闭包转发给具体视图。
///
/// Debug 构建下，在分发到具体 renderer 后，会在消息行右上角叠加一个
/// `renderer.id` 徽章，便于调试时一眼分辨当前生效的具体渲染器
/// （包括第三方插件贡献的）。Release 构建下不显示。
struct MessageRowView: View {
    let services: MessageListServices
    let message: Message
    let verbosity: LumiResponseVerbosity

    private var renderer: MessageRendererItem? {
        services.rendering?.renderer(for: message)
    }

    var body: some View {
        Group {
            if let renderer {
                renderer.render(message, verbosity)
                    .messageRendererIdBadge(renderer.id)
            } else {
                Text("No renderer for message: \(message.id)")
                    .foregroundColor(.orange)
                    .padding(12)
            }
        }
    }
}

/// 在消息行的右上角显示当前 `MessageRendererItem.id` 的小徽章。
struct MessageRendererIdBadge: View {
    @LumiTheme private var theme

    /// renderer id，来自 `MessageRendererItem.id`。
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
    /// 仅 Debug 构建有效；Release 构建下此方法为 no-op。
    func messageRendererIdBadge(_ id: String) -> some View {
        #if DEBUG
            overlay(alignment: .topTrailing) {
                MessageRendererIdBadge(id: id)
            }
        #else
            self
        #endif
    }
}
