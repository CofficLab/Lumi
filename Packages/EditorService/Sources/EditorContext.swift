import Foundation
import LumiUI

/// Bridges editor file-tree and chrome views to the active `EditorService`.
@MainActor
public final class EditorContext: ObservableObject {
    public static let syncSelectedFileNotificationName = Notification.Name("EditorContext.syncSelectedFile")

    @Published public private(set) var fileTreeHighlightedFileURL: URL?

    private let service: EditorService
    private let themeVM: AppThemeVM

    public var currentFileURL: URL? { service.currentFileURL }
    public var activeChromeTheme: (any LumiAppChromeTheme)? { themeVM.activeChromeTheme }
    public var activeFileIconTheme: LumiFileIconThemeContributor? { LumiDefaultFileIconThemeContributor() }

    public init(service: EditorService, themeVM: AppThemeVM = .shared) {
        self.service = service
        self.themeVM = themeVM
    }

    public func setFileTreeHighlightedFileURL(_ url: URL) {
        fileTreeHighlightedFileURL = url
    }

    public func openFile(at url: URL) {
        service.open(at: url)
    }

    public func refreshProjectContext(for projectPath: String) async {
        await service.refreshProjectContext(for: projectPath)
    }

    public func syncFileTreeHighlightFromEditor() {
        fileTreeHighlightedFileURL = service.currentFileURL
    }

    /// Intentionally no-op: Editor workspace has no chat integration.
    public func addToConversation(fileURL: URL, windowId: UUID?) {}
}
