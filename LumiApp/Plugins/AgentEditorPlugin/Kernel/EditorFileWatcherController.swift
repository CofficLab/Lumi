import Foundation

@MainActor
final class EditorFileWatcherController {
    func setup(
        for url: URL,
        externalFileController: EditorExternalFileController,
        onPoll: @escaping @MainActor (_ url: URL, _ currentModDate: Date) -> Void,
        cleanup: @escaping @MainActor () -> Void,
        logInfo: (String) -> Void
    ) {
        externalFileController.cleanupWatcher(clearConflict: cleanup)
        externalFileController.setupWatcher(for: url, onPoll: onPoll)
        logInfo("已启动文件轮询监听：\(url.lastPathComponent)")
    }

    func cleanup(
        externalFileController: EditorExternalFileController,
        clearConflict: @escaping @MainActor () -> Void
    ) {
        externalFileController.cleanupWatcher(clearConflict: clearConflict)
    }
}
