import Combine
import Foundation
import LumiKernel
import LumiUI

/// Bridges editor file-tree and chrome views to the active `EditorService`.
///
/// 同时作为 `FileTreeEditorCoordination` 的实现,向 kernel 注册,供文件树等 UI 组件
/// 通过协议消费编辑器协同能力(打开/关闭/迁移 session、高亮、加入对话等),
/// 而无需直接依赖 `EditorService` 包。
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

    /// 文件树高亮 URL 的变化流(协议要求)。
    /// 将 `@Published fileTreeHighlightedFileURL` 的投影 publisher 暴露为 `AnyPublisher`。
    public var fileTreeHighlightPublisher: AnyPublisher<URL?, Never> {
        $fileTreeHighlightedFileURL.eraseToAnyPublisher()
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

// MARK: - FileTreeEditorCoordination

/// `EditorContext` 实现文件树协同能力协议,向 kernel 注册后,文件树等 UI 组件
/// 可通过 `kernel.resolveService(FileTreeEditorCoordination.self)` 取用,
/// 无需直接依赖 `EditorService` 包。
extension EditorContext: FileTreeEditorCoordination {}

// MARK: - EditorTabStripCoordination

/// `EditorContext` 实现标签栏协同能力协议,向 kernel 注册后,标签栏等 UI 组件
/// 可通过 `kernel.resolveService(EditorTabStripCoordination.self)` 取用,
/// 无需直接依赖 `EditorService` 包。
extension EditorContext: EditorTabStripCoordination {
    public var currentTabs: [TabDescriptor] {
        service.sessions.tabs.map(TabDescriptor.init)
    }

    public var currentActiveSessionID: UUID? {
        service.sessions.activeSessionID
    }

    /// 标签栏状态流:合并 `sessionStore.$tabs` 与 `.$activeSessionID`,映射为
    /// 跨包值类型 `TabStripState`。
    public var tabStripStatePublisher: AnyPublisher<TabStripState, Never> {
        Publishers.CombineLatest(service.sessionStore.$tabs, service.sessionStore.$activeSessionID)
            .map { tabs, activeSessionID in
                TabStripState(
                    tabs: tabs.map(TabDescriptor.init),
                    activeSessionID: activeSessionID
                )
            }
            .eraseToAnyPublisher()
    }

    public func activateSession(id: UUID) {
        service.sessions.activateAndRestoreSession(id: id)
    }

    public func openFileSessionInBackground(at url: URL) {
        _ = service.sessions.openFileSessionInBackground(at: url)
    }

    /// 关闭标签:封装"保存未保存内容 + 关闭 session + 加载下一个 session 文件 + 恢复交互状态"
    /// 的完整副作用,使 UI 层无需感知 files/session 的协作细节。
    @discardableResult
    public func closeSession(id: UUID) -> UUID? {
        let wasActive = service.sessions.activeSessionID == id
        if wasActive, service.files.hasUnsavedChanges {
            service.files.saveNow()
        }
        let nextSession = service.sessions.closeSession(id: id)
        if wasActive, let nextSession {
            service.files.loadFile(from: nextSession.fileURL)
            service.files.applySessionRestore(nextSession)
        }
        return nextSession?.id
    }

    /// 关闭除指定标签外的所有标签(含保存与加载副作用)。
    public func closeOtherSessions(keeping id: UUID) {
        if service.files.currentFileURL != service.sessions.session(for: id)?.fileURL,
           service.files.hasUnsavedChanges {
            service.files.saveNow()
        }
        let kept = service.sessions.closeOtherSessions(keeping: id)
        service.files.loadFile(from: kept?.fileURL)
        if let kept {
            service.files.applySessionRestore(kept)
        }
    }

    /// 关闭指定标签左侧的所有标签(含保存与加载副作用)。
    public func closeTabsToLeft(of id: UUID) {
        closeTabsOnSide(of: id, closesActiveSession: activeSessionIsLeftOf(tab: id)) { tabID in
            service.sessions.closeTabsToLeft(of: tabID)
        }
    }

    /// 关闭指定标签右侧的所有标签(含保存与加载副作用)。
    public func closeTabsToRight(of id: UUID) {
        closeTabsOnSide(of: id, closesActiveSession: activeSessionIsRightOf(tab: id)) { tabID in
            service.sessions.closeTabsToRight(of: tabID)
        }
    }

    /// 关闭一侧标签的通用副作用封装(与 ItemView 原逻辑等价)。
    private func closeTabsOnSide(
        of tabID: UUID,
        closesActiveSession: Bool,
        close: (UUID) -> EditorSession?
    ) {
        let previousActive = service.sessions.activeSessionID
        if closesActiveSession, service.files.hasUnsavedChanges {
            service.files.saveNow()
        }
        let nextSession = close(tabID)
        guard nextSession?.id != previousActive else { return }
        service.files.loadFile(from: nextSession?.fileURL)
        if let nextSession {
            service.files.applySessionRestore(nextSession)
        }
    }

    private func activeSessionIsLeftOf(tab tabID: UUID) -> Bool {
        guard let activeID = service.sessions.activeSessionID,
              let activeIndex = service.sessions.tabs.firstIndex(where: { $0.sessionID == activeID }),
              let targetIndex = service.sessions.tabs.firstIndex(where: { $0.sessionID == tabID }) else {
            return false
        }
        return activeIndex < targetIndex
    }

    private func activeSessionIsRightOf(tab tabID: UUID) -> Bool {
        guard let activeID = service.sessions.activeSessionID,
              let activeIndex = service.sessions.tabs.firstIndex(where: { $0.sessionID == activeID }),
              let targetIndex = service.sessions.tabs.firstIndex(where: { $0.sessionID == tabID }) else {
            return false
        }
        return activeIndex > targetIndex
    }

    public func togglePinned(sessionID: UUID) {
        service.sessions.togglePinned(sessionID: sessionID)
    }

    @discardableResult
    public func reorderSession(sessionID: UUID, before beforeSessionID: UUID?) -> Bool {
        service.sessions.reorderSession(sessionID: sessionID, before: beforeSessionID)
    }
}

/// `EditorTab` → `TabDescriptor` 的桥接(解耦 UI 层与 EditorService 类型)。
extension TabDescriptor {
    init(_ tab: EditorTab) {
        self.init(
            sessionID: tab.sessionID,
            fileURL: tab.fileURL,
            title: tab.title,
            isDirty: tab.isDirty,
            isPinned: tab.isPinned,
            isPreview: tab.isPreview
        )
    }
}
