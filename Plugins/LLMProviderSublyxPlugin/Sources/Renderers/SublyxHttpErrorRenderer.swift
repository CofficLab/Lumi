import LumiCoreKit
import SwiftUI

enum SublyxHttpErrorRenderer {
    static let item = LumiMessageRendererItem(
        id: "sublyx-http-error",
        order: SublyxPlugin.info.order + 210,
        canRender: { message in
            SublyxRenderKind.isSublyxError(message) && SublyxRenderKind.httpStatusCode(from: message.renderKind) != nil
        },
        render: { message, showRawMessage in
            guard let statusCode = SublyxRenderKind.httpStatusCode(from: message.renderKind) else {
                return AnyView(EmptyView())
            }
            return AnyView(SublyxHttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage))
        }
    )
}
