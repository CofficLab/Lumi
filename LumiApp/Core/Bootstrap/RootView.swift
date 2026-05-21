import Combine
import Foundation
import MagicAlert
import SwiftData
import SwiftUI

/// 根视图容器组件
/// 为应用提供统一的上下文环境，管理核心服务初始化和环境注入
///
/// ## 架构说明
///
/// 全局共享 VM 通过 `RootContainer.shared` 注入。
/// 窗口级 VM 通过 `WindowContainer` 注入，每个窗口拥有独立的 VM 实例。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView(container: windowContainer)
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 窗口容器（每窗口独立）
    @ObservedObject var windowContainer: WindowContainer

    /// 全局服务容器（单例）。
    @StateObject var container = RootContainer.shared

    init(container: WindowContainer, @ViewBuilder content: () -> Content) {
        self._windowContainer = ObservedObject(wrappedValue: container)
        self.content = content()
    }

    var body: some View {
        ZStack {
            RootListener(scope: windowContainer)
            content
                .withMagicToast()
                // 全局 VM（所有窗口共享）
                .environmentObject(container.windowManagerVM)
                .environmentObject(container.themeVM)
                .environmentObject(container.providerRegistry)
                .environmentObject(container.pluginVM)
                .environmentObject(container.messageRendererVM)
                .environmentObject(container.conversationTurnServices)
                .environmentObject(container.agentSessionConfig)
                .environmentObject(container.chatHistoryVM)
                .environmentObject(container.recentProjectsVM)
                .environmentObject(container.gitVM)
                .environmentObject(container.idleTimeVM)
                // 窗口级 VM（每窗口独立）
                .environmentObject(windowContainer.editorVM)
                .environmentObject(windowContainer.conversationVM)
                .environmentObject(windowContainer.projectVM)
                .environmentObject(windowContainer.layoutVM)
                .environmentObject(windowContainer.messageQueueVM)
                .environmentObject(windowContainer.agentAttachmentsVM)
                .environmentObject(windowContainer.inputQueueVM)
                .environmentObject(windowContainer.chatDraftVM)
                .environmentObject(windowContainer.permissionHandlingVM)
                .environmentObject(windowContainer.commandSuggestionVM)
                .environmentObject(windowContainer.permissionRequestVM)
                .environmentObject(windowContainer.taskCancellationVM)
                .environmentObject(windowContainer.chatTimelineViewModel)
                .environmentObject(windowContainer.conversationSendStatusVM)
                .environmentObject(windowContainer.projectContextRequestVM)
                .environment(\.windowContainer, windowContainer)
                .modelContainer(container.modelContainer)
        }
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Parameter container: 窗口容器
    /// - Returns: 包装在 RootView 中的视图
    func inRootView(container: WindowContainer) -> some View {
        RootView(container: container, content: { self })
    }

    /// Preview 专用：使用 fallback WindowContainer 注入环境对象
    ///
    /// 生产代码请使用 `inRootView(container:)` 传入窗口容器。
    /// 此方法仅用于 #Preview 和设置窗口等无窗口上下文的场景。
    func inRootView() -> some View {
        inRootView(container: WindowContainer(container: RootContainer.shared))
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(container: WindowContainer(container: RootContainer.shared))
        .withDebugBar()
}
