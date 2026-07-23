import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// MessageRenderer 插件 OnReady 阶段钩子
///
/// 负责 onReady 阶段的所有注册逻辑
@MainActor
public struct MessageRendererOnReadyHook {
    public nonisolated static let baseOrder: Int = 10

    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 注册 Manager
        kernel.registerMessageRendererManagerService(MessageRendererManager.shared)

        // 注册内置渲染器
        guard let manager = kernel.resolveService(MessageRendererManaging.self) else {
            return
        }

        let base = Self.baseOrder

        // 优先级最高：turn-completed / status 特殊渲染
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-turn-completed",
                order: base + 320,
                canRender: { message in
                    message.renderKind == "turn-completed" || message.content == LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    TurnCompletedMessageView(message: message)
                }
            )
        )

        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-status-message",
                order: base + 310,
                canRender: { message in
                    message.role == .status
                        && message.renderKind != "turn-completed"
                        && message.content != LumiChatMarkers.turnCompleted
                },
                render: { message, _ in
                    StatusMessageView(message: message)
                }
            )
        )

        // 错误消息：让 Provider 特定渲染器优先
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-error-message",
                order: base + 290,
                canRender: { message in
                    guard message.role == .error || message.isError else { return false }
                    if let renderKind = message.renderKind,
                       ProviderRenderKindManager.shared.isProviderSpecificRenderKind(renderKind) {
                        return false
                    }
                    return true
                },
                render: { message, showRawMessage in
                    ErrorMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 工具结果
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-tool-message",
                order: base + 240,
                canRender: { message in
                    message.role == .tool
                },
                render: { message, showRawMessage in
                    ToolMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 用户消息
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-user-message",
                order: base + 190,
                canRender: { message in
                    message.role == .user
                },
                render: { message, showRawMessage in
                    UserMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 助手消息
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-assistant-message",
                order: base + 180,
                canRender: { message in
                    message.role == .assistant
                },
                render: { message, showRawMessage in
                    AssistantMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 系统消息
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-system-message",
                order: base + 150,
                canRender: { message in
                    message.role == .system
                },
                render: { message, showRawMessage in
                    SystemMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )

        // 兜底 Markdown 渲染
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-default-markdown",
                order: base - 10,
                canRender: { message in
                    !message.content.isEmpty
                },
                render: { message, showRawMessage in
                    DefaultMessageView(message: message, showRawMessage: showRawMessage)
                }
            )
        )
    }
}
