import Combine
import Foundation
import LumiUI

/// Bridges editor file-tree and chrome views to the active `EditorService`.
@MainActor
public final class EditorContext: ObservableObject {
    public static let syncSelectedFileNotificationName = Notification.Name("EditorContext.syncSelectedFile")

    @Published public private(set) var fileTreeHighlightedFileURL: URL?

    private let service: EditorService
    private let themeVM: AppThemeVM
    private var cancellables = Set<AnyCancellable>()

    public var currentFileURL: URL? { service.files.currentFileURL }
    public var activeChromeTheme: (any LumiAppChromeTheme)? { themeVM.activeChromeTheme }
    public var activeFileIconTheme: LumiFileIconThemeContributor? { LumiDefaultFileIconThemeContributor() }

    public init(service: EditorService, themeVM: AppThemeVM = .shared) {
        self.service = service
        self.themeVM = themeVM
        fileTreeHighlightedFileURL = service.files.currentFileURL
        bindFileTreeHighlightToEditorCurrentFile()
    }

    public func resolvedFileTreeHighlightURL() -> URL? {
        EditorFileTreeHighlightResolver.resolve(
            highlighted: fileTreeHighlightedFileURL,
            current: currentFileURL
        )
    }

    public func setFileTreeHighlightedFileURL(_ url: URL) {
        fileTreeHighlightedFileURL = url
    }

    public func openFile(at url: URL) {
        service.sessions.open(at: url)
    }

    /// 关闭 fileURL 匹配给定 URL 的编辑器 session（用于文件树删除后清理残留 tab）。
    /// - Parameter urls: 已删除的文件/目录 URL 列表。
    public func closeSessions(forURLs urls: [URL]) {
        let targets = Set(urls.map { $0.standardizedFileURL })
        guard !targets.isEmpty else { return }

        // 收集匹配的 session id（按 tab.fileURL 精确匹配）
        let sessionIDsToClose = service.sessions.tabs
            .compactMap { tab -> EditorSession.ID? in
                guard let fileURL = tab.fileURL else { return nil }
                // 目录被删除时，其下所有已打开文件也需关闭
                return targets.contains { fileURL.standardizedFileURL == $0 } ? tab.sessionID : nil
            }
        for id in Set(sessionIDsToClose) {
            service.sessions.closeSession(id: id)
        }
    }

    /// 关闭旧路径的编辑器 tab 并打开新路径（用于文件树重命名后迁移 tab）。
    /// - Parameters:
    ///   - oldURL: 重命名前的文件 URL。
    ///   - newURL: 重命名后的文件 URL。
    public func replaceSessionURL(from oldURL: URL, to newURL: URL) {
        closeSessions(forURLs: [oldURL])
        openFile(at: newURL)
    }

    public func refreshProjectContext(for projectPath: String) async {
        await service.refreshProjectContext(for: projectPath)
    }

    public func syncFileTreeHighlightFromEditor() {
        fileTreeHighlightedFileURL = service.files.currentFileURL
    }

    public static let addToChatNotificationName = Notification.Name("addToChat")

    /// 将文件路径加入当前窗口的对话输入区（与拖入输入区行为一致，由 Chat 侧处理图片附件）。
    public func addToConversation(fileURL: URL, windowId: UUID?) {
        addToConversation(fileURLs: [fileURL], windowId: windowId)
    }

    /// 将多个文件路径加入当前窗口的对话输入区。
    public func addToConversation(fileURLs: [URL], windowId: UUID?) {
        for fileURL in fileURLs {
            let standardized = fileURL.standardizedFileURL
            let resolvedWindowId = windowId ?? service.state.windowId
            var userInfo: [String: Any] = ["fileURL": standardized.path]
            if let resolvedWindowId {
                userInfo["windowId"] = resolvedWindowId
            }
            NotificationCenter.default.post(
                name: Self.addToChatNotificationName,
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func bindFileTreeHighlightToEditorCurrentFile() {
        service.state.$currentFileURL
            .receive(on: RunLoop.main)
            .sink { [weak self] url in
                guard let self else { return }
                guard let url else {
                    self.fileTreeHighlightedFileURL = nil
                    return
                }
                guard !EditorFileTreeHighlightResolver.isSameFile(self.fileTreeHighlightedFileURL, url) else {
                    return
                }
                self.fileTreeHighlightedFileURL = url
            }
            .store(in: &cancellables)
    }
}
