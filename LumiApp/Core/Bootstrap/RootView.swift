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
/// 窗口级 VM 通过 `WindowScope` 注入，每个窗口拥有独立的 VM 实例。
///
/// ## 使用方式
///
/// ```swift
/// ContentLayout()
///     .inRootView(scope: windowScope)
/// ```
struct RootView<Content>: View where Content: View {
    /// 视图内容
    var content: Content

    /// 窗口作用域（每窗口独立）
    @ObservedObject var scope: WindowScope

    /// 全局服务容器（单例）。
    @StateObject var container = RootContainer.shared

    init(scope: WindowScope, @ViewBuilder content: () -> Content) {
        self._scope = ObservedObject(wrappedValue: scope)
        self.content = content()
    }

    var body: some View {
        RootEventMonitorView(scope: scope) {
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
                .environmentObject(scope.editorVM)
                .environmentObject(scope.conversationVM)
                .environmentObject(scope.projectVM)
                .environmentObject(scope.layoutVM)
                .environmentObject(scope.messageQueueVM)
                .environmentObject(scope.agentAttachmentsVM)
                .environmentObject(scope.inputQueueVM)
                .environmentObject(scope.chatDraftVM)
                .environmentObject(scope.permissionHandlingVM)
                .environmentObject(scope.commandSuggestionVM)
                .environmentObject(scope.permissionRequestVM)
                .environmentObject(scope.taskCancellationVM)
                .environmentObject(scope.chatTimelineViewModel)
                .environmentObject(scope.conversationSendStatusVM)
                .environmentObject(scope.projectContextRequestVM)
                .environment(\.windowScope, scope)
                .modelContainer(container.modelContainer)
        }
    }
}

extension View {
    /// 将视图包装在 RootView 中，注入所有必要的环境对象和模型容器
    /// - Parameter scope: 窗口作用域
    /// - Returns: 包装在 RootView 中的视图
    func inRootView(scope: WindowScope) -> some View {
        RootView(scope: scope, content: { self })
    }

    /// Preview 专用：使用 fallback WindowScope 注入环境对象
    ///
    /// 生产代码请使用 `inRootView(scope:)` 传入窗口作用域。
    /// 此方法仅用于 #Preview 和设置窗口等无窗口上下文的场景。
    func inRootView() -> some View {
        inRootView(scope: WindowScope(container: RootContainer.shared))
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .inRootView(scope: WindowScope(container: RootContainer.shared))
        .withDebugBar()
}
