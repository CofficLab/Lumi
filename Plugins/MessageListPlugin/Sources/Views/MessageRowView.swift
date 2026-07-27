import LumiKernel
import LumiKernel
import SwiftUI

/// Renders a single message using the injected message renderer,
/// or a fallback if no renderer is available.
struct MessageRowView: View {
    let message: LumiChatMessage
    let renderer: LumiMessageRendererItem?
    @Binding var showRawMessage: Bool

    var body: some View {
        Group {
            if let renderer {
                renderer.render(message, $showRawMessage)
            } else {
                Text("No renderer for message: \(message.id)")
                    .foregroundColor(.orange)
                    .padding(12)
            }
        }
    }
}
