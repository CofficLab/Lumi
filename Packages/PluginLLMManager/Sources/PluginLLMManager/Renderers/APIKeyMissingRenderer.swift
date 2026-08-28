import ProviderLLMManager
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// API Key 缺失消息渲染器：优先于 `core-error-message`(order=300) 接管，
/// 渲染可内联输入 Key 的 `ProviderAPIKeyMissingView`。
enum APIKeyMissingRenderer {
    @MainActor
    static func item(manager: any LLMManaging) -> MessageRendererItem {
        MessageRendererItem(
            id: LLMProviderAPIKeyMessage.missingRenderKind,
            order: 350,
            canRender: { message in
                LLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message)
            },
            render: { message, _ in
                AnyView(ProviderAPIKeyMissingView(message: message, manager: manager))
            }
        )
    }
}
