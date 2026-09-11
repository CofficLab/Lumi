import ProviderLLMManager
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// API Key 读取失败（Keychain 访问异常）消息渲染器。
enum APIKeyAccessFailedRenderer {
    @MainActor
    static func item(capability: any LLMManagerCapability) -> MessageRendererItem {
        MessageRendererItem(
            id: LLMProviderAPIKeyMessage.accessFailedRenderKind,
            order: 340,
            canRender: { message in
                LLMProviderAPIKeyMessage.isAPIKeyAccessFailedMessage(message)
            },
            render: { message, _ in
                let viewModel = ProviderAPIKeyViewModel(
                    capability: capability,
                    message: message
                )
                return AnyView(ProviderAPIKeyAccessFailedView(message: message, viewModel: viewModel))
            }
        )
    }
}
