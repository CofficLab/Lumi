import LumiCoreKit
import SwiftUI

/// 智谱其他 HTTP 错误渲染器（`zhipu-http-{code}`，不含 401/403）
struct HttpErrorRenderer: SuperMessageRenderer {
    static let id = "http-error"
    static let priority = 210

    func canRender(message: ChatMessage) -> Bool {
        ZhipuRenderKind.matchesOtherHttpError(message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        let statusCode = ZhipuRenderKind.httpStatusCode(from: message.renderKind)
            ?? ZhipuRenderKind.legacyHttpStatusCode(from: message.content)
        return AnyView(HttpErrorView(message: message, statusCode: statusCode, showRawMessage: showRawMessage))
    }
}
