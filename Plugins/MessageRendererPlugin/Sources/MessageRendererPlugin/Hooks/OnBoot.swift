import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// MessageRenderer 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的 MessageRendererManager 服务注册,以及所有内置核心渲染器
/// 的注册,确保在 onReady 之前内核已持有 MessageRendererManaging。
@MainActor
public struct MessageRendererOnBootHook {
    public nonisolated static let baseOrder: Int = 10

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        // 注册 Manager
        try kernel.registerMessageRendererManagerService(MessageRendererManager.shared)

        // 注册内置渲染器
        guard let manager = kernel.resolveService(MessageRendering.self) else {
            return
        }

        let base = Self.baseOrder

        // 优先级最高:turn-completed / status 特殊渲染
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
                render: { message, verbosity in
                    StatusMessageView(message: message, verbosity: verbosity)
                }
            )
        )

        // 错误消息:让 Provider 特定渲染器优先
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
                render: { message, verbosity in
                    ErrorMessageView(message: message, verbosity: verbosity)
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
                render: { message, verbosity in
                    ToolMessageView(message: message, verbosity: verbosity)
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
                render: { message, verbosity in
                    UserMessageView(kernel: kernel, message: message, verbosity: verbosity)
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
                render: { message, verbosity in
                    AssistantMessageView(message: message, verbosity: verbosity)
                }
            )
        )

        // 工具步骤组合成消息(数据层把连续多条「只含工具调用的助手消息」合并成一条)。
        // 优先级高于普通助手消息:V1 走可折叠步骤组,V2/V3 复用助手气泡(多个工具卡片聚在一起)。
        manager.registerMessageRenderer(
            LumiMessageRendererItem(
                id: "core-tool-step-group",
                order: base + 185,
                canRender: { message in
                    message.renderKind == "tool-step-group" || message.renderKind == "turn-activity"
                },
                render: { message, verbosity in
                    ToolStepGroupMessageView(message: message, verbosity: verbosity)
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
                render: { message, verbosity in
                    SystemMessageView(message: message, verbosity: verbosity)
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
                render: { message, verbosity in
                    DefaultMessageView(message: message, verbosity: verbosity)
                }
            )
        )
    }
}
