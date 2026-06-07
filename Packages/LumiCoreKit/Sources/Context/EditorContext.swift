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

    /// 文件树当前高亮的文件 URL。
    ///
    /// 与 `currentFileURL` 分离，避免 Rail 内容视图重建或编辑器异步打开时，
    /// 文件树高亮回退到上一个文件。
    @Published public private(set) var fileTreeHighlightedFileURL: URL?

    /// 文件树正在打开的目标文件；用于在编辑器异步加载完成前保护高亮。
    private var fileTreeOpeningFileURL: URL?

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

    /// 更新文件树高亮（文件树点击时立即调用）。
    public func setFileTreeHighlightedFileURL(_ url: URL?) {
        let standardized = url?.standardizedFileURL
        fileTreeHighlightedFileURL = standardized
        fileTreeOpeningFileURL = standardized
    }

    /// 取消进行中的文件树打开请求（连续点击或视图销毁时调用）。
    public func clearFileTreeOpeningFileURL() {
        fileTreeOpeningFileURL = nil
    }

    /// 将文件树高亮与编辑器当前文件对齐（内核在 EditorService 确认切换后调用）。
    public func syncFileTreeHighlightFromEditor() {
        let editorURL = currentFileURL?.standardizedFileURL
        guard let editorURL else {
            fileTreeHighlightedFileURL = nil
            fileTreeOpeningFileURL = nil
            return
        }

        if let openingURL = fileTreeOpeningFileURL {
            if editorURL == openingURL {
                fileTreeOpeningFileURL = nil
                fileTreeHighlightedFileURL = editorURL
            }
            return
        }

        fileTreeHighlightedFileURL = editorURL
    }

    // MARK: - Actions

    /// 打开指定文件。
    public func openFile(at url: URL) {
        updateCurrentFileURL(url)
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
