import LumiCoreKit
import SwiftUI

/// 智谱 HTTP 401 认证失败渲染器（`zhipu-http-401`）
struct Http401Renderer: SuperMessageRenderer {
    static let id = "http-401"
    static let priority = 210

    func canRender(message: ChatMessage) -> Bool {
        ZhipuRenderKind.matchesHttp(statusCode: 401, message: message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ApiKeyMissingView(message: message, showRawMessage: showRawMessage))
    }
}
