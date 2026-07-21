import LumiKernel
import SwiftUI

/// Chat Panel 插件
///
/// 注册 Chat 视图容器的 ActivityBar 图标。
/// 当图标激活时，通过 `onContainerActivated` 调整工作区状态：
/// 显示 Rail、不需要 main content 区域、显示 Chat。
@MainActor
public final class ChatPanelPlugin: LumiPlugin {
    public let id = "com.coffic.lumi.plugin.chat-panel"
    public let name = "Chat"
    public let order = 78
    public static let policy: LumiPluginPolicy = .alwaysOn

    public init() {}

    public func register(kernel: LumiKernel) throws {}

    public func boot(kernel: LumiKernel) async throws {}

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "bubble.left.and.bubble.right.fill"
            )
        ]
    }

    // MARK: - Workspace State

    public func workspaceVisibility(kernel: LumiKernel) -> WorkspaceVisibility {
        // Chat 容器始终显示 activity bar + rail + chat，不需要 main content
        WorkspaceVisibility(
            rail: true,
            chat: true,
            content: false,
            activityBar: true,
            panel: false
        )
    }

    public func onContainerActivated(kernel: LumiKernel, containerID: String) {
        guard containerID == id else { return }
        kernel.workspaceState?.applyVisibility(
            rail: true,
            chat: true,
            content: false,
            activityBar: true,
            panel: false
        )
    }
}