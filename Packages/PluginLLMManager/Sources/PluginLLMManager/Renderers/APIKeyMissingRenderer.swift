import ProviderLLMManager
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// API Key 缺失消息渲染器：优先于 `core-error-message`(order=300) 接管，
/// 渲染可内联输入 Key 的 `ProviderAPIKeyMissingView`。
enum APIKeyMissingRenderer {
    @MainActor
    static func item(capability: any LLMManagerCapability) -> MessageRendererItem {
        MessageRendererItem(
            id: LLMProviderAPIKeyMessage.missingRenderKind,
            order: 350,
            canRender: { message in
                LLMProviderAPIKeyMessage.isMissingAPIKeyMessage(message)
            },
            render: { message, _ in
                let viewModel = ProviderAPIKeyViewModel(
                    capability: capability,
                    message: message
                )
                return AnyView(ProviderAPIKeyMissingView(message: message, viewModel: viewModel))
            }
        )
    }
}
