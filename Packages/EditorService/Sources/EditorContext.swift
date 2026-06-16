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
