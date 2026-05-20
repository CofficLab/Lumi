import Foundation
import LumiPreviewKit

/// EditorPreview 插件专属存储根目录与相关预览构建路径。
///
/// 存储位置：`AppConfig.getPluginDBFolderURL(pluginName: "EditorPreviewPlugin")/`
enum EditorPreviewStorage {
    struct CacheSummary: Equatable {
        let fileCount: Int
        let byteCount: Int64

        var isEmpty: Bool {
            fileCount == 0 || byteCount == 0
        }

        var formattedByteCount: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: byteCount)
        }
    }

    static let pluginName = "EditorPreviewPlugin"
    private static let installLock = NSLock()
    private nonisolated(unsafe) static var didInstall = false

    static func installIfNeeded() {
        installLock.lock()
        let root = AppConfig.getPluginDBFolderURL(pluginName: pluginName)
        let paths = LumiPreviewFacade.PreviewStoragePaths(rootDirectory: root)
        if !didInstall {
            didInstall = true
            try? paths.ensureDirectoriesExist()
            for directory in [
                root.appendingPathComponent("inline-builder-workspace", isDirectory: true),
                root.appendingPathComponent("DerivedData", isDirectory: true)
            ] {
                try? FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        }
        installLock.unlock()

        LumiPreviewFacade.PreviewStorage.configure(paths)
    }

    static var rootDirectory: URL {
        installIfNeeded()
        return AppConfig.getPluginDBFolderURL(pluginName: pluginName)
    }

    static var inlineBuilderWorkspaceDirectory: URL {
        rootDirectory.appendingPathComponent("inline-builder-workspace", isDirectory: true)
    }

    static var derivedDataDirectory: URL {
        rootDirectory.appendingPathComponent("DerivedData", isDirectory: true)
    }

    static func cacheSummary() -> CacheSummary {
        summarize(directories: cacheManagedDirectories)
    }

    static func purgeBuildCaches() {
        for directory in cacheManagedDirectories {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    private static var cacheManagedDirectories: [URL] {
        let paths = LumiPreviewFacade.PreviewStorage.paths
        return [
            inlineBuilderWorkspaceDirectory,
            derivedDataDirectory,
            paths.previewEntryCacheDirectory,
            paths.entryCacheDirectory,
            paths.compileCommandCacheDirectory,
            paths.workDirectory
        ]
    }

    private static func summarize(directories: [URL]) -> CacheSummary {
        var fileCount = 0
        var byteCount: Int64 = 0
        let fileManager = FileManager.default

        for directory in directories {
            guard let enumerator = fileManager.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                      values.isRegularFile == true else {
                    continue
                }
                fileCount += 1
                byteCount += Int64(values.fileSize ?? 0)
            }
        }

        return CacheSummary(fileCount: fileCount, byteCount: byteCount)
    }
}
