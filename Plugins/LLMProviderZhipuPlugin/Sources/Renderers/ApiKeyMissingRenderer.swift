import LumiCoreKit
import SwiftUI

/// 智谱 API Key 未配置错误渲染器（`zhipu-api-key-missing`）
struct ApiKeyMissingRenderer: SuperMessageRenderer {
    static let id = "api-key-missing"
    static let priority = 210

    func canRender(message: ChatMessage) -> Bool {
        ZhipuRenderKind.matchesApiKeyMissing(message)
    }

    @MainActor
    func render(message: ChatMessage, showRawMessage: Binding<Bool>) -> AnyView {
        AnyView(ApiKeyMissingView(message: message, showRawMessage: showRawMessage))
    }
}
