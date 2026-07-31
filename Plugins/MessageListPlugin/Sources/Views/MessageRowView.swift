import LumiKernel
import SwiftUI

/// Renders a single message using the injected message renderer,
/// or a fallback if no renderer is available.
///
/// `verbosity` 由 `MessageListView` 计算并显式传入，再由 `LumiMessageRendererItem.render`
/// 闭包转发给具体视图。
struct MessageRowView: View {
    let message: LumiChatMessage
    let renderer: LumiMessageRendererItem?
    let verbosity: LumiResponseVerbosity

    var body: some View {
        Group {
            if let renderer {
                renderer.render(message, verbosity)
            } else {
                Text("No renderer for message: \(message.id)")
                    .foregroundColor(.orange)
                    .padding(12)
            }
        }
    }
}