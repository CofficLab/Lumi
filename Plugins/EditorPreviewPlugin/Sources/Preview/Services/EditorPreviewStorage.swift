import Foundation
import LumiKernel
import LumiPreviewKit

/// EditorPreview 插件专属存储根目录与相关预览构建路径。
///
/// 存储位置：`<LumiCore.dataRootDirectory>/EditorPreviewPlugin/`
public enum EditorPreviewStorage {
    public struct CacheSummary: Equatable, Sendable {
        public let fileCount: Int
        public let byteCount: Int64

        public var isEmpty: Bool {
            fileCount == 0 || byteCount == 0
        }

        public var formattedByteCount: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useKB, .useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: byteCount)
        }
    }

    public static let pluginName = "EditorPreviewPlugin"
    static let legacyPluginNames = ["EditorPreviewPlugin", "EditorInlinePreviewPlugin"]
    public static let autoCleanupPolicy = LumiPreviewFacade.PreviewStorageAutoCleaner.Policy(
        maximumAge: 14 * 24 * 60 * 60,
        maximumSizeBytes: 2 * 1024 * 1024 * 1024,
        targetSizeBytes: 1024 * 1024 * 1024
    )
    private static let installLock = NSLock()
    private nonisolated(unsafe) static var didInstall = false
    private nonisolated(unsafe) static var lastCacheCleanupAt: Date = .distantPast
    private static let cacheCleanupInterval: TimeInterval = 60 * 60

    public static func installIfNeeded() {
        installLock.lock()
        defer { installLock.unlock() }

        let root = EditorPreviewPluginRuntimeBridge.pluginDirectory
            ?? EditorPreviewPluginRuntimeBridge.fallbackRootDirectory.appendingPathComponent(pluginName, isDirectory: true)
        let paths = LumiPreviewFacade.PreviewStoragePaths(rootDirectory: root)
        if !didInstall {
            didInstall = true
            try? paths.ensureDirectoriesExist()
            for directory in [
                root.appendingPathComponent("inline-builder-workspace", isDirectory: true),
                root.appendingPathComponent("DerivedData", isDirectory: true),
                root.appendingPathComponent("build-logs", isDirectory: true)
            ] {
                try? FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )
            }
        }

        LumiPreviewFacade.PreviewStorage.configure(paths)
    }

    public static var rootDirectory: URL {
        installIfNeeded()
        return EditorPreviewPluginRuntimeBridge.pluginDirectory
            ?? EditorPreviewPluginRuntimeBridge.fallbackRootDirectory.appendingPathComponent(pluginName, isDirectory: true)
    }

    public static var inlineBuilderWorkspaceDirectory: URL {
        rootDirectory.appendingPathComponent("inline-builder-workspace", isDirectory: true)
    }

    public static var derivedDataDirectory: URL {
        rootDirectory.appendingPathComponent("DerivedData", isDirectory: true)
    }

    /// 构建日志目录，存放每次预览构建失败的完整日志。
    public static var buildLogsDirectory: URL {
        rootDirectory.appendingPathComponent("build-logs", isDirectory: true)
    }

    public static func cacheSummary() -> CacheSummary {
        summarize(directories: cacheManagedDirectories)
    }

    public static func refreshCacheSummary() -> CacheSummary {
        cleanBuildCachesIfNeeded()
        return cacheSummary()
    }

    public static func purgeBuildCaches() {
        for directory in cacheManagedDirectories {
            try? FileManager.default.removeItem(at: directory)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    @discardableResult
    public static func cleanBuildCachesIfNeeded(
        now: Date = Date(),
        paths: LumiPreviewFacade.PreviewStoragePaths = LumiPreviewFacade.PreviewStorage.paths
    ) -> LumiPreviewFacade.PreviewStorageAutoCleaner.Result {
        installLock.lock()
        guard now.timeIntervalSince(lastCacheCleanupAt) >= cacheCleanupInterval else {
            installLock.unlock()
            return .empty
        }
        lastCacheCleanupAt = now
        installLock.unlock()

        return LumiPreviewFacade.PreviewStorageAutoCleaner.clean(
            directories: cacheManagedDirectories(paths: paths),
            policy: autoCleanupPolicy,
            now: now
        )
    }

    private static var cacheManagedDirectories: [URL] {
        cacheManagedDirectories(paths: LumiPreviewFacade.PreviewStorage.paths)
    }

    static func cacheManagedDirectories(
        paths: LumiPreviewFacade.PreviewStoragePaths
    ) -> [URL] {
        cacheRootCandidates(currentRoot: paths.rootDirectory).flatMap { root in
            cacheManagedDirectories(root: root)
        }
    }

    static func cacheRootCandidates(
        currentRoot: URL,
        fileManager: FileManager = .default
    ) -> [URL] {
        var roots = [currentRoot]
        let currentDBDirectory = currentRoot.deletingLastPathComponent()
        let appSupportDirectory = currentDBDirectory.deletingLastPathComponent()

        guard let dbDirectories = try? fileManager.contentsOfDirectory(
            at: appSupportDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return uniqueURLs(roots)
        }

        for dbDirectory in dbDirectories {
            guard dbDirectory.lastPathComponent.hasPrefix("db_"),
                  (try? dbDirectory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                continue
            }

            for pluginName in legacyPluginNames {
                let candidate = dbDirectory.appendingPathComponent(pluginName, isDirectory: true)
                var isDirectory: ObjCBool = false
                if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    roots.append(candidate)
                }
            }
        }

        return uniqueURLs(roots)
    }

    private static func cacheManagedDirectories(root: URL) -> [URL] {
        let paths = LumiPreviewFacade.PreviewStoragePaths(rootDirectory: root)
        return [
            root.appendingPathComponent("inline-builder-workspace", isDirectory: true),
            root.appendingPathComponent("DerivedData", isDirectory: true),
            root.appendingPathComponent("build-logs", isDirectory: true),
            paths.previewEntryCacheDirectory,
            paths.entryCacheDirectory,
            paths.compileCommandCacheDirectory,
            paths.workDirectory
        ]
    }

    private static func uniqueURLs(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { url in
            seen.insert(url.standardizedFileURL.path).inserted
        }
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
