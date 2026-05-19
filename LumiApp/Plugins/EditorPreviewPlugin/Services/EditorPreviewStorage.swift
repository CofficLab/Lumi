import Foundation
import LumiPreviewKit

/// EditorPreview 插件专属存储根目录与 LumiPreviewKit 路径配置。
///
/// 存储位置：`AppConfig.getPluginDBFolderURL()/EditorPreviewPlugin/`
enum EditorPreviewStorage {
    static let pluginName = "EditorPreviewPlugin"
    private static let installLock = NSLock()
    private nonisolated(unsafe) static var didInstall = false

    static func installIfNeeded() {
        installLock.lock()
        defer { installLock.unlock() }
        guard !didInstall else { return }
        didInstall = true

        let root = AppConfig.getPluginDBFolderURL(pluginName: pluginName)
        let paths = LumiPreviewFacade.PreviewStoragePaths(rootDirectory: root)
        try? paths.ensureDirectoriesExist()
        LumiPreviewFacade.PreviewStorage.configure(paths)
    }

    static var rootDirectory: URL {
        installIfNeeded()
        return AppConfig.getPluginDBFolderURL(pluginName: pluginName)
    }

    static var projectPreviewHistoryURL: URL {
        rootDirectory.appendingPathComponent("project-preview-history.json", isDirectory: false)
    }
}
