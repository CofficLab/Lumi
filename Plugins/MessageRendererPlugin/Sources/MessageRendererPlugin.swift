import LumiCoreKit
import SwiftUI

public enum MessageRendererPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "CoreMessageRenderer",
        displayName: LumiPluginLocalization.string("核心消息渲染器", bundle: .module),
        description: LumiPluginLocalization.string("提供内置消息类型的渲染支持", bundle: .module),
        order: 10,
        category: .general,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "paintbrush.fill",
    )


    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        [
            LumiMessageRendererItem(
                id: "core-turn-completed",
                order: info.order + 320,
                canRender: { $0.renderKind == "turn-completed" || $0.content == LumiChatMarkers.turnCompleted },
                render: { message, _ in
                    TurnCompletedMessageView(message: message)
                }
            ),
            LumiMessageRendererItem(
                id: "core-status-message",
                order: info.order + 310,
                canRender: {
                    $0.role == .status && $0.renderKind != "turn-completed" && $0.content != LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    StatusMessageView(message: message)
                }
            ),
            LumiMessageRendererItem(
                id: "core-error-message",
                order: info.order + 290,
                canRender: { message in
                    guard message.role == .error || message.isError else {
                        return false
                    }
                    if let renderKind = message.renderKind,
                       ProviderRenderKindManager.shared.isProviderSpecificRenderKind(renderKind) {
                        return false
                    }
                    return true
                },
                render: { message, showRawMessage in
                    ErrorMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-tool-message",
                order: info.order + 240,
                canRender: { $0.role == .tool },
                render: { message, showRawMessage in
                    ToolMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-user-message",
                order: info.order + 190,
                canRender: { $0.role == .user },
                render: { message, showRawMessage in
                    UserMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-assistant-message",
                order: info.order + 180,
                canRender: { $0.role == .assistant },
                render: { message, showRawMessage in
                    AssistantMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-system-message",
                order: info.order + 150,
                canRender: { $0.role == .system },
                render: { message, showRawMessage in
                    SystemMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-default-markdown",
                order: info.order - 10,
                canRender: { !$0.content.isEmpty },
                render: { message, showRawMessage in
                    DefaultMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
        ]
    }
}
