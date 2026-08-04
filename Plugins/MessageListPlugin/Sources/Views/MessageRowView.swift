import LumiKernel
import SwiftUI

/// Renders a single message using the injected message renderer,
/// or a fallback if no renderer is available.
///
/// `verbosity` 由 `MessageListView` 计算并显式传入，再由 `LumiMessageRendererItem.render`
/// 闭包转发给具体视图。
///
/// Debug 构建下,在分发到具体 renderer 后,会在消息行右上角叠加一个
/// `renderer.id` 徽章,便于调试时一眼分辨当前生效的具体渲染器
/// (包括第三方插件贡献的)。Release 构建下不显示。
struct MessageRowView: View {
    let kernel: LumiKernel
    let message: LumiChatMessage
    let verbosity: LumiResponseVerbosity

    private var renderer: LumiMessageRendererItem? {
        kernel.messageRendererManager?.renderer(for: message)
    }

    var body: some View {
        Group {
            if let renderer {
                #if DEBUG
                renderer.render(message, verbosity)
                    .messageRendererIdBadge(renderer.id)
                #else
                renderer.render(message, verbosity)
                #endif
            } else {
                Text("No renderer for message: \(message.id)")
                    .foregroundColor(.orange)
                    .padding(12)
            }
        }
    }
}