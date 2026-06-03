import Combine
import Foundation
import LumiUI
import SwiftUI

/// 编辑器上下文桥接，用于在 Package 插件视图中访问编辑器状态。
///
/// 由内核在 `RootView` 中初始化并通过 `.environmentObject()` 注入，
/// 替代直接依赖 app 侧的 `WindowEditorVM`，使文件树等包化插件视图
/// 无需依赖 `EditorService` 即可获取当前选中文件和执行编辑器操作。
@MainActor
public final class EditorContext: ObservableObject {
    // MARK: - Theme

    /// 当前激活的 Chrome 主题。
    public var activeChromeTheme: (any LumiAppChromeTheme)? {
        themeProvider()
    }

    /// 当前激活的文件图标主题。
    public var activeFileIconTheme: (any LumiFileIconThemeContributor)? {
        fileIconThemeProvider()
    }

    // MARK: - Editor State

    /// 当前选中的文件 URL。
    @Published public private(set) var currentFileURL: URL?

    // MARK: - Callbacks (由内核注入)

    /// 打开文件。
    public var openFileHandler: @MainActor (URL) -> Void = { _ in }

    /// 刷新项目上下文。
    public var refreshProjectContextHandler: @MainActor (String) async -> Void = { _ in }

    /// 将文件添加到当前对话。
    public var addToConversationHandler: @MainActor (URL, UUID?) -> Void = { _, _ in }

    /// 同步选中文件通知名称（由内核注入，包侧视图用它监听文件选择事件）。
    public static var syncSelectedFileNotificationName: Notification.Name?

    // MARK: - Providers (由内核注入)

    private var themeProvider: @MainActor () -> (any LumiAppChromeTheme)? = { nil }
    private var fileIconThemeProvider: @MainActor () -> (any LumiFileIconThemeContributor)? = { nil }

    // MARK: - Init

    public init() {}

    // MARK: - Configuration (内核调用)

    /// 注入主题提供者。
    public func configureThemeProvider(_ provider: @escaping @MainActor () -> (any LumiAppChromeTheme)?) {
        themeProvider = provider
        objectWillChange.send()
    }

    /// 注入文件图标主题提供者。
    public func configureFileIconThemeProvider(_ provider: @escaping @MainActor () -> (any LumiFileIconThemeContributor)?) {
        fileIconThemeProvider = provider
        objectWillChange.send()
    }

    /// 更新当前选中文件 URL（内核调用）。
    public func updateCurrentFileURL(_ url: URL?) {
        currentFileURL = url
    }

    // MARK: - Actions

    /// 打开指定文件。
    public func openFile(at url: URL) {
        openFileHandler(url)
    }

    /// 刷新项目上下文。
    public func refreshProjectContext(for projectPath: String) async {
        await refreshProjectContextHandler(projectPath)
    }

    /// 将文件添加到当前对话。
    public func addToConversation(fileURL: URL, windowId: UUID?) {
        addToConversationHandler(fileURL, windowId)
    }
}
