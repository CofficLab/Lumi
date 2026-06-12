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

    public var currentFileURL: URL? { service.currentFileURL }
    public var activeChromeTheme: (any LumiAppChromeTheme)? { themeVM.activeChromeTheme }
    public var activeFileIconTheme: LumiFileIconThemeContributor? { LumiDefaultFileIconThemeContributor() }

    public init(service: EditorService, themeVM: AppThemeVM = .shared) {
        self.service = service
        self.themeVM = themeVM
        fileTreeHighlightedFileURL = service.currentFileURL
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
