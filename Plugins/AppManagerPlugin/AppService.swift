import Foundation
import AppKit
import MagicKit
import OSLog
import SwiftUI

/// 应用服务
class AppService: SuperLog {
    static let emoji = "📦"
    static let verbose = false

    private let cacheManager = CacheManager.shared

    // 标准应用安装路径
    private let standardPaths = [
        "/Applications",
        "/System/Applications",
        "~/Applications",
        "~/Desktop",
    ]

    // 用户特定的应用路径
    private func getUserApplicationPaths() -> [String] {
        var paths = standardPaths

        // 添加其他可能的路径
        if let homeDir = FileManager.default.homeDirectoryForCurrentUser.path as String? {
            paths.append(contentsOf: [
                "\(homeDir)/Downloads",
            ])
        }

        return paths
    }
    
    private let libraryPaths = [
        "Library/Application Support",
        "Library/Caches",
        "Library/Preferences",
        "Library/Saved Application State",
        "Library/Containers",
        "Library/Logs",
        "Library/Cookies",
        "Library/WebKit"
    ]

    /// 扫描已安装的应用（在后台线程执行）
    /// - Parameter force: 是否强制重新扫描（忽略缓存）
    func scanInstalledApps(force: Bool = false) async -> [AppModel] {
        return await withCheckedContinuation { continuation in
            // 在后台队列执行文件操作
            let paths = self.getUserApplicationPaths()
            let t = self.t
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    if Self.verbose {
                        os_log("\(t)正在扫描已安装应用 (force: \(force))")
                    }
    
                    var apps: [AppModel] = []
                    var validPaths = Set<String>()

                    for path in paths {
                        let expandedPath = NSString(string: path).expandingTildeInPath
                        guard let url = URL(string: "file://\(expandedPath)") else { continue }

                        if let directoryContents = try? FileManager.default.contentsOfDirectory(
                            at: url,
                            includingPropertiesForKeys: [.contentModificationDateKey],
                            options: [.skipsHiddenFiles]
                        ) {
                            for appURL in directoryContents where appURL.pathExtension == "app" {
                                validPaths.insert(appURL.path)

                                // 获取文件修改时间
                                let resourceValues = try? appURL.resourceValues(forKeys: [.contentModificationDateKey])
                                let modDate = resourceValues?.contentModificationDate ?? Date()

                                // 尝试从缓存加载 (如果未强制刷新)
                                if !force, let cachedItem = self.cacheManager.getCachedApp(at: appURL.path, currentModificationDate: modDate) {
                                    let app = AppModel(
                                        bundleURL: appURL,
                                        name: cachedItem.name,
                                        identifier: cachedItem.identifier,
                                        version: cachedItem.version,
                                        iconFileName: cachedItem.iconFileName,
                                        size: cachedItem.size
                                    )
                                    apps.append(app)
                                } else {
                                    let app = AppModel(bundleURL: appURL)
                                    apps.append(app)
                                }
                            }
                        }
                    }

                    // 清理无效缓存并保存
                    Task { @MainActor in
                         self.cacheManager.cleanInvalidCache(keeping: validPaths)
                         self.cacheManager.saveCache()
                         
                         let stats = self.cacheManager.getStats()
                         if Self.verbose {
                             os_log("\(t)缓存统计: \(stats.hitCount) 次命中, \(stats.missCount) 次未命中, \(String(format: "%.1f", stats.hitRate * 100))% 命中率")
                         }
                    }

                    let sortedApps = apps.sorted {
                        $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                    }

                    os_log("\(t)扫描完成: 发现 \(sortedApps.count) 个应用")
                    continuation.resume(returning: sortedApps)
                }
            }
        }
    }

    /// 计算任意路径的大小
    func calculateSize(for url: URL) async -> Int64 {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    continuation.resume(returning: 0)
                    return
                }
                
                // 如果是文件，直接返回大小
                if let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                   let isDirectory = resourceValues.isDirectory, !isDirectory,
                   let fileSize = resourceValues.fileSize {
                    continuation.resume(returning: Int64(fileSize))
                    return
                }
                
                // 如果是目录，递归计算
                var totalSize: Int64 = 0
                if let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.fileSizeKey],
                    options: [.skipsHiddenFiles]
                ) {
                    for case let fileURL as URL in enumerator {
                        if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                           let fileSize = resourceValues.fileSize {
                            totalSize += Int64(fileSize)
                        }
                    }
                }
                continuation.resume(returning: totalSize)
            }
        }
    }

    /// 计算应用大小（在后台线程执行）
    func calculateAppSize(for app: AppModel) async -> Int64 {
        let size = await calculateSize(for: app.bundleURL)
        
        // 更新缓存
        let resourceValues = try? app.bundleURL.resourceValues(forKeys: [.contentModificationDateKey])
        let modDate = resourceValues?.contentModificationDate ?? Date()
        self.cacheManager.updateCache(for: app, size: size, modificationDate: modDate)
        
        return size
    }
    
    /// 扫描应用的关联文件
    func scanRelatedFiles(for app: AppModel) async -> [RelatedFile] {
        guard let bundleId = app.bundleIdentifier else { return [] }
        let home = NSHomeDirectory()
        var relatedFiles: [RelatedFile] = []
        let fileManager = FileManager.default
        
        // 1. 添加 App 本身
        // 注意：AppModel 可能还没有计算大小，或者已经计算了。为了准确，这里重新获取（或者直接用 AppModel 的如果已存在）
        // 这里为了确保一致性，我们重新计算或直接使用 app.size
        let appSize = app.size > 0 ? app.size : await calculateSize(for: app.bundleURL)
        relatedFiles.append(RelatedFile(path: app.bundleURL.path, size: appSize, type: .app))
        
        // 2. 扫描 Library
        await withTaskGroup(of: RelatedFile?.self) { group in
            for libSubPath in libraryPaths {
                let fullPath = "\(home)/\(libSubPath)"
                
                group.addTask {
                    // 策略 A: 精确匹配 Bundle ID
                    let candidatePath1 = "\(fullPath)/\(bundleId)"
                    if fileManager.fileExists(atPath: candidatePath1) {
                        let size = await self.calculateSize(for: URL(fileURLWithPath: candidatePath1))
                        return RelatedFile(path: candidatePath1, size: size, type: self.getType(from: libSubPath))
                    }
                    
                    // 策略 B: 匹配 App Name (主要针对 Application Support)
                    if libSubPath.contains("Application Support") {
                        // 使用 app.displayName 可能不准确，尽量用 bundleName
                        let name = app.bundleName // 这是从 Info.plist 读出来的
                        let candidatePath2 = "\(fullPath)/\(name)"
                        if fileManager.fileExists(atPath: candidatePath2) {
                             // 简单匹配
                             let size = await self.calculateSize(for: URL(fileURLWithPath: candidatePath2))
                             return RelatedFile(path: candidatePath2, size: size, type: self.getType(from: libSubPath))
                        }
                    }
                    
                    // 策略 C: Preferences plist
                    if libSubPath.contains("Preferences") {
                        let plistPath = "\(fullPath)/\(bundleId).plist"
                        if fileManager.fileExists(atPath: plistPath) {
                            let size = await self.calculateSize(for: URL(fileURLWithPath: plistPath))
                            return RelatedFile(path: plistPath, size: size, type: .preferences)
                        }
                    }
                    
                    // 策略 D: Saved State
                    if libSubPath.contains("Saved Application State") {
                         let statePath = "\(fullPath)/\(bundleId).savedState"
                         if fileManager.fileExists(atPath: statePath) {
                             let size = await self.calculateSize(for: URL(fileURLWithPath: statePath))
                             return RelatedFile(path: statePath, size: size, type: .state)
                         }
                    }
                    
                    return nil
                }
            }
            
            for await result in group {
                if let file = result {
                    relatedFiles.append(file)
                }
            }
        }
        
        return relatedFiles
    }
    
    private func getType(from path: String) -> RelatedFile.RelatedFileType {
        if path.contains("Application Support") { return .support }
        if path.contains("Caches") { return .cache }
        if path.contains("Preferences") { return .preferences }
        if path.contains("Saved Application State") { return .state }
        if path.contains("Containers") { return .container }
        if path.contains("Logs") { return .log }
        return .other
    }
    
    /// 删除指定的文件列表
    func deleteFiles(_ files: [RelatedFile]) async throws {
        let fileManager = FileManager.default
        for file in files {
            // 使用 trashItem 放入废纸篓，比较安全
            try fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
        }
    }

    /// 保存缓存
    func saveCache() {
        cacheManager.saveCache()
    }

    /// 卸载应用
    func uninstallApp(_ app: AppModel) async throws {
        os_log("\(self.t)准备卸载应用: \(app.displayName)")

        let fileManager = FileManager.default
        let appPath = app.bundleURL.path

        // 检查应用是否存在
        guard fileManager.fileExists(atPath: appPath) else {
            os_log(.error, "\(self.t)应用不存在: \(appPath)")
            throw AppError.appNotFound
        }

        // 检查是否有写入权限
        guard fileManager.isWritableFile(atPath: appPath) else {
            os_log(.error, "\(self.t)权限不足: \(appPath)")
            throw AppError.permissionDenied
        }

        // 移到废纸篓
        try fileManager.trashItem(at: app.bundleURL, resultingItemURL: nil)
        os_log("\(self.t)应用已移至废纸篓: \(app.displayName)")
    }

    /// 在 Finder 中显示应用
    func revealInFinder(_ app: AppModel) {
        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
    }

    /// 打开应用
    func openApp(_ app: AppModel) {
        NSWorkspace.shared.open(app.bundleURL)
    }

    /// 获取应用信息
    func getAppInfo(_ app: AppModel) -> String {
        var info = [String]()

        info.append("名称: \(app.displayName)")
        if let identifier = app.bundleIdentifier {
            info.append("Bundle ID: \(identifier)")
        }
        if let version = app.version {
            info.append("版本: \(version)")
        }
        info.append("路径: \(app.bundleURL.path)")

        return info.joined(separator: "\n")
    }
}

enum AppError: LocalizedError {
    case appNotFound
    case permissionDenied
    case uninstallFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "应用不存在"
        case .permissionDenied:
            return "没有权限卸载此应用"
        case .uninstallFailed(let reason):
            return "卸载失败: \(reason)"
        }
    }
}

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .withNavigation(AppManagerPlugin.navigationId)
        .inRootView()
        .withDebugBar()
}
