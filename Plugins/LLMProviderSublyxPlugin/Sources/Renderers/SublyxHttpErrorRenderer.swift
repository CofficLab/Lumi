import KernelLumi
import KernelLumi
import LLMKit
import SwiftUI

enum SublyxHttpErrorRenderer {
    private static let pluginOrder = 104 // SublyxPlugin.order

    static let item = LumiMessageRendererItem(
        id: "sublyx-http-error",
        order: pluginOrder + 210,
        canRender: { message in
            SublyxRenderKind.isSublyxError(message) && SublyxRenderKind.httpStatusCode(from: message.renderKind) != nil
        },
        render: { message, _ in
            let statusCode = SublyxRenderKind.httpStatusCode(from: message.renderKind) ?? 0
            return AnyView(SublyxHttpErrorView(message: message, statusCode: statusCode))
        }
    )
}
