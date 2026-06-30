import LumiCoreKit
import SwiftUI

public enum MessageRendererPlugin: LumiPlugin {
    public static let info = LumiPluginInfo(
        id: "CoreMessageRenderer",
        displayName: LumiPluginLocalization.string("核心消息渲染器", bundle: .module),
        description: LumiPluginLocalization.string("提供内置消息类型的渲染支持", bundle: .module),
        order: 10
    )

    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .general
    public static let iconName = "paintbrush.fill"

    @MainActor
    public static func messageRenderers(context: LumiPluginContext) -> [LumiMessageRendererItem] {
        [
            LumiMessageRendererItem(
                id: "core-turn-completed",
                order: 330,
                canRender: { $0.renderKind == "turn-completed" || $0.content == LumiChatMarkers.turnCompleted },
                render: { message, _ in
                    TurnCompletedMessageView(message: message)
                }
            ),
            LumiMessageRendererItem(
                id: "core-status-message",
                order: 320,
                canRender: {
                    $0.role == .status && $0.renderKind != "turn-completed" && $0.content != LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    StatusMessageView(message: message)
                }
            ),
            LumiMessageRendererItem(
                id: "core-error-message",
                order: 300,
                canRender: { message in
                    guard message.role == .error || message.isError else {
                        return false
                    }
                    if let renderKind = message.renderKind,
                       renderKind.hasPrefix("zhipu-")
                           || renderKind.hasPrefix("aliyun-")
                           || renderKind.hasPrefix("xiaomi-")
                           || renderKind.hasPrefix("mlx-")
                           || renderKind.hasPrefix("sublyx-") {
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
                order: 250,
                canRender: { $0.role == .tool },
                render: { message, showRawMessage in
                    ToolMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-user-message",
                order: 200,
                canRender: { $0.role == .user },
                render: { message, showRawMessage in
                    UserMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-assistant-message",
                order: 190,
                canRender: { $0.role == .assistant },
                render: { message, showRawMessage in
                    AssistantMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-system-message",
                order: 160,
                canRender: { $0.role == .system },
                render: { message, showRawMessage in
                    SystemMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
            LumiMessageRendererItem(
                id: "core-default-markdown",
                order: 0,
                canRender: { !$0.content.isEmpty },
                render: { message, showRawMessage in
                    DefaultMessageView(message: message, showRawMessage: showRawMessage)
                }
            ),
        ]
    }
}
