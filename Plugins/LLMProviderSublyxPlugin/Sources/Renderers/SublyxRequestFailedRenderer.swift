import LumiCoreKit
import SwiftUI

enum SublyxRequestFailedRenderer {
    static let item = LumiMessageRendererItem(
        id: "sublyx-request-failed",
        order: 200,
        canRender: { message in
            SublyxRenderKind.matches(renderKind: SublyxRenderKind.requestFailed, message: message)
        },
        render: { message, showRawMessage in
            SublyxRequestFailedView(message: message, showRawMessage: showRawMessage)
        }
    )
}
