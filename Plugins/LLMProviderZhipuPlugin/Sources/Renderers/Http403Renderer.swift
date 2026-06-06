import LumiCoreKit
import SwiftUI

/// 智谱 HTTP 403 权限拒绝渲染器（`zhipu-http-403`）
struct Http403Renderer: SuperMessageRenderer {
    static let id = "http-403"
    static let priority = 210

    func canRender(message: ChatMessage) -> Bool {
        ZhipuRenderKind.matchesHttp(statusCode: 403, message: message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(HttpErrorView(message: message, statusCode: 403, showRawMessage: showRawMessage))
    }
}
