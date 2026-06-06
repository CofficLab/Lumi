import LumiCoreKit
import SwiftUI

/// 智谱通用请求失败渲染器（`zhipu-request-failed`）
struct RequestFailedRenderer: SuperMessageRenderer {
    static let id = "request-failed"
    static let priority = 210

    func canRender(message: ChatMessage) -> Bool {
        ZhipuRenderKind.matches(renderKind: ZhipuRenderKind.requestFailed, message: message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(HttpErrorView(message: message, statusCode: nil, showRawMessage: showRawMessage))
    }
}
