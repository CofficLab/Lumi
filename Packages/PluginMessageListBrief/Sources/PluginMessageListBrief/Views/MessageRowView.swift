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
/// 开启开发者模式后，在分发到具体 renderer 后会在消息行右上角叠加一个
/// `renderer.id` 徽章，便于一眼分辨当前生效的具体渲染器（包括第三方插件贡献的），
/// 并用同一 ID 的稳定颜色绘制细边框。
struct MessageRowView: View {
    let services: MessageListServices
    let message: Message
    let verbosity: ResponseVerbosity
    let isDeveloperModeEnabled: Bool

    init(
        services: MessageListServices,
        message: Message,
        verbosity: ResponseVerbosity,
        isDeveloperModeEnabled: Bool
    ) {
        self.services = services
        self.message = message
        self.verbosity = verbosity
        self.isDeveloperModeEnabled = isDeveloperModeEnabled
    }

    private var renderer: MessageRendererItem? {
        services.rendering?.renderer(for: message)
    }

    var body: some View {
        Group {
            if let renderer {
                renderer.render(message, verbosity)
                    .messageRendererIdBadge(renderer.id, isEnabled: isDeveloperModeEnabled)
            } else {
                Text("No renderer for message: \(message.id)")
                    .foregroundColor(.orange)
                    .padding(12)
            }
        }
    }
}

/// 在开发者模式下于消息行右上角显示当前 `MessageRendererItem.id` 的小徽章。
struct MessageRendererIdBadge: View {
    @LumiTheme private var theme

    /// renderer id，来自 `MessageRendererItem.id`。
    let id: String

    private var rendererColor: Color {
        MessageRendererDeveloperModeColor.color(for: id)
    }

    var body: some View {
        Text(id)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundColor(theme.textSecondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                rendererColor.opacity(0.10),
                in: Capsule(style: .continuous)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(rendererColor.opacity(0.45), lineWidth: 0.5)
            )
            .fixedSize()
    }
}

extension View {
    /// 在视图右上角叠加当前 renderer 的 `id` 徽章。
    @ViewBuilder
    func messageRendererIdBadge(_ id: String, isEnabled: Bool) -> some View {
        if isEnabled {
            overlay {
                Rectangle()
                    .stroke(MessageRendererDeveloperModeColor.color(for: id).opacity(0.75), lineWidth: 0.5)
            }
            .overlay(alignment: .topTrailing) {
                MessageRendererIdBadge(id: id)
            }
        } else {
            self
        }
    }
}

private enum MessageRendererDeveloperModeColor {
    static func color(for id: String) -> Color {
        Color(
            hue: hue(for: id),
            saturation: 0.65,
            brightness: 0.85
        )
    }

    private static func hue(for id: String) -> Double {
        var hash: UInt32 = 2_166_136_261
        for byte in id.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Double(hash) / Double(UInt32.max)
    }
}
