import LumiCoreChat
import LumiCoreLLMProvider
import LumiCoreMessage
import LumiKernel
import LumiUI
import SwiftUI

@MainActor
public final class MessageRendererPlugin: LumiPlugin {
    public nonisolated static let baseOrder: Int = 10

    public let id = "CoreMessageRenderer"
    public let name = "核心消息渲染器"
    public let order = 10

    public init() {}

    public func register(kernel: LumiKernel) throws {
        // 直接向内核注册消息渲染器
        guard let manager = kernel.resolveService(MessageRendererManagerProviding.self) else {
            return
        }

        let base = Self.baseOrder

        // 优先级最高：turn-completed / status 特殊渲染
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-turn-completed",
                order: base + 320,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return message.renderKind == "turn-completed" || message.content == LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    TurnCompletedMessageView(message: message as! LumiChatMessage)
                }
            )
        )

        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-status-message",
                order: base + 310,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return message.role == .status
                        && message.renderKind != "turn-completed"
                        && message.content != LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    StatusMessageView(message: message as! LumiChatMessage)
                }
            )
        )

        // 错误消息：让 Provider 特定渲染器优先
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-error-message",
                order: base + 290,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    guard message.role == .error || message.isError else { return false }
                    if let renderKind = message.renderKind,
                       ProviderRenderKindManager.shared.isProviderSpecificRenderKind(renderKind) {
                        return false
                    }
                    return true
                },
                render: { message, showRawMessage in
                    ErrorMessageView(message: message as! LumiChatMessage, showRawMessage: showRawMessage)
                }
            )
        )

        // 工具结果
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-tool-message",
                order: base + 240,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return message.role == .tool
                },
                render: { message, showRawMessage in
                    ToolMessageView(message: message as! LumiChatMessage, showRawMessage: showRawMessage)
                }
            )
        )

        // 用户消息
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-user-message",
                order: base + 190,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return message.role == .user
                },
                render: { message, showRawMessage in
                    UserMessageView(message: message as! LumiChatMessage, showRawMessage: showRawMessage)
                }
            )
        )

        // 助手消息
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-assistant-message",
                order: base + 180,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return message.role == .assistant
                },
                render: { message, showRawMessage in
                    AssistantMessageView(message: message as! LumiChatMessage, showRawMessage: showRawMessage)
                }
            )
        )

        // 系统消息
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-system-message",
                order: base + 150,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return message.role == .system
                },
                render: { message, showRawMessage in
                    SystemMessageView(message: message as! LumiChatMessage, showRawMessage: showRawMessage)
                }
            )
        )

        // 兜底 Markdown 渲染
        manager.registerMessageRenderer(
            MessageRendererItem(
                id: "core-default-markdown",
                order: base - 10,
                canRender: { msg in
                    guard let message = msg as? LumiChatMessage else { return false }
                    return !message.content.isEmpty
                },
                render: { message, showRawMessage in
                    DefaultMessageView(message: message as! LumiChatMessage, showRawMessage: showRawMessage)
                }
            )
        )
    }

    public func boot(kernel: LumiKernel) async throws {}
}
