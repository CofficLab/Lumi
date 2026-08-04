import LumiKernel
import LumiKernel
import LLMKit
import SwiftUI

enum SublyxRequestFailedRenderer {
    private static let pluginOrder = 104 // SublyxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "sublyx-request-failed",
        order: pluginOrder + 190,
        canRender: { message in
            SublyxRenderKind.matches(renderKind: SublyxRenderKind.requestFailed, message: message)
        },
        render: { message, _ in
            SublyxRequestFailedView(message: message)
        }
    )
}
