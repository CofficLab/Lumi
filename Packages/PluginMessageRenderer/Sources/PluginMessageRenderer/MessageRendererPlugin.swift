import KernelCore
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// 核心消息渲染器插件（KernelCore 版本）。
///
/// 复刻自旧版 `MessageRendererPlugin`（KernelLumi / LumiPlugin）：
/// - `onBoot` 中把 10 个内置核心渲染器注册进 `MessageRenderingProviding`
///   （优先级与旧版完全一致：turn-completed / status 最高，default-markdown 兜底）；
/// - `onShutdown` 撤回全部注册，保持可卸载。
@MainActor
public final class MessageRendererPlugin: SuperPlugin {
    public let id = "CoreMessageRenderer"
    public let order = 10

    public let metadata = PluginMetadata(
        id: "CoreMessageRenderer",
        name: "核心消息渲染器",
        description: "消息渲染：用户/助手/系统/错误/状态/工具消息与工具调用卡片",
        category: .chat,
        stage: .preview,
        policy: .required
    )

    /// 渲染器优先级基数（与旧版一致）。
    public nonisolated static let baseOrder: Int = 10

    private let rendererIDs: [String] = [
        "core-turn-completed",
        "core-status-message",
        "core-error-message",
        "core-tool-message",
        "core-user-message",
        "core-tool-step-group",
        "core-assistant-message",
        "core-system-message",
        "core-default-markdown",
    ]

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let manager = kernel.resolveProvider((any MessageRenderingProviding).self) else { return }
        let base = Self.baseOrder

        // 优先级最高：turn-completed / status 特殊渲染
        manager.register(MessageRendererItem(
            id: "core-turn-completed",
            order: base + 320,
            canRender: { message in
                message.renderKind == "turn-completed" || message.content == LumiChatMarkers.turnCompleted
            },
            render: { message, _ in
                AnyView(TurnCompletedMessageView(message: message))
            }
        ))

        manager.register(MessageRendererItem(
            id: "core-status-message",
            order: base + 310,
            canRender: { message in
                message.role == .status
                    && message.renderKind != "turn-completed"
                    && message.content != LumiChatMarkers.turnCompleted
            },
            render: { message, verbosity in
                AnyView(StatusMessageView(message: message, verbosity: verbosity))
            }
        ))

        // 错误消息：让 Provider 特定渲染器优先
        manager.register(MessageRendererItem(
            id: "core-error-message",
            order: base + 290,
            canRender: { message in
                message.role == .error || message.isError
            },
            render: { message, verbosity in
                AnyView(ErrorMessageView(message: message, verbosity: verbosity))
            }
        ))

        // 工具结果
        manager.register(MessageRendererItem(
            id: "core-tool-message",
            order: base + 240,
            canRender: { message in
                message.role == .tool
            },
            render: { message, verbosity in
                AnyView(ToolMessageView(message: message, verbosity: verbosity))
            }
        ))

        // 用户消息
        manager.register(MessageRendererItem(
            id: "core-user-message",
            order: base + 190,
            canRender: { message in
                message.role == .user
            },
            render: { message, verbosity in
                AnyView(UserMessageView(kernel: kernel, message: message, verbosity: verbosity))
            }
        ))

        // 工具步骤组合成消息（数据层把连续多条「只含工具调用的助手消息」合并成一条）。
        // 优先级高于普通助手消息：V1 走可折叠步骤组，V2/V3 复用助手气泡。
        manager.register(MessageRendererItem(
            id: "core-tool-step-group",
            order: base + 185,
            canRender: { message in
                message.renderKind == "tool-step-group" || message.renderKind == "turn-activity"
            },
            render: { message, verbosity in
                AnyView(ToolStepGroupMessageView(kernel: kernel, message: message, verbosity: verbosity))
            }
        ))

        // 助手消息
        manager.register(MessageRendererItem(
            id: "core-assistant-message",
            order: base + 180,
            canRender: { message in
                message.role == .assistant
            },
            render: { message, verbosity in
                AnyView(AssistantMessageView(kernel: kernel, message: message, verbosity: verbosity))
            }
        ))

        // 系统消息
        manager.register(MessageRendererItem(
            id: "core-system-message",
            order: base + 150,
            canRender: { message in
                message.role == .system
            },
            render: { message, verbosity in
                AnyView(SystemMessageView(message: message, verbosity: verbosity))
            }
        ))

        // 兜底渲染器：order 最低，只要没有任何更高优先级的 renderer 能处理，就由它接管。
        manager.register(MessageRendererItem(
            id: "core-default-markdown",
            order: base - 10,
            canRender: { _ in true },
            render: { message, verbosity in
                AnyView(DefaultMessageView(message: message, verbosity: verbosity))
            }
        ))
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let manager = kernel.resolveProvider((any MessageRenderingProviding).self)
        for id in rendererIDs {
            manager?.unregister(id: id)
        }
    }
}
