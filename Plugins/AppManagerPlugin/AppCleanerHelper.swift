import Foundation
import OSLog

/// 应用清理助手，用于扫描和清理应用的关联文件
class AppCleanerHelper {
    private let logger = Logger(subsystem: "com.coffic.lumi", category: "AppCleanerHelper")
    private let fileManager = FileManager.default
    
    // 常见的关联文件搜索路径
    private let searchPaths: [FileManager.SearchPathDirectory] = [
        .applicationSupportDirectory,
        .cachesDirectory,
        .libraryDirectory, // 用于 Preferences, Logs, Saved Application State 等
    ]
    
    // 具体的子目录名称
    private let subDirectories = [
        "Preferences",
        "Saved Application State",
        "Logs",
        "WebKit",
        "Containers",
        "Group Containers"
    ]
    
    /// 扫描应用的关联文件
    /// - Parameter app: 目标应用
    /// - Returns: 关联文件的 URL 列表
    func scanRelatedFiles(for app: AppModel) -> [URL] {
        var relatedFiles: [URL] = []
        let appName = app.bundleName
        let bundleID = app.bundleIdentifier ?? ""
        
        logger.info("开始扫描应用关联文件: \(appName), BundleID: \(bundleID)")
        
        // 1. 扫描 Application Support 和 Caches
        let userLibURL = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first!
        
        let targetDirs: [String] = [
            "Application Support",
            "Caches",
            "Logs",
            "Preferences",
            "Saved Application State",
            "WebKit",
            "Containers"
        ]
        
        for dirName in targetDirs {
            let dirURL = userLibURL.appendingPathComponent(dirName)
            guard fileManager.fileExists(atPath: dirURL.path) else { continue }
            
            // 尝试直接匹配 Bundle ID
            if !bundleID.isEmpty {
                // 精确匹配 Bundle ID
                let exactMatchURL = dirURL.appendingPathComponent(bundleID)
                if fileManager.fileExists(atPath: exactMatchURL.path) {
                    relatedFiles.append(exactMatchURL)
                }
                
                // Preferences 通常是 com.example.app.plist
                if dirName == "Preferences" {
                    let plistURL = dirURL.appendingPathComponent("\(bundleID).plist")
                    if fileManager.fileExists(atPath: plistURL.path) {
                        relatedFiles.append(plistURL)
                    }
                }
            }
            
            // 尝试匹配应用名称 (通常用于 Application Support)
            if !appName.isEmpty {
                let nameMatchURL = dirURL.appendingPathComponent(appName)
                if fileManager.fileExists(atPath: nameMatchURL.path) {
                    // 避免误删，确保不是系统关键目录
                    if isValidDeletionTarget(nameMatchURL) {
                        relatedFiles.append(nameMatchURL)
                    }
                }
            }
        }
        
        // 去重
        let uniqueFiles = Array(Set(relatedFiles))
        logger.info("扫描完成，找到 \(uniqueFiles.count) 个关联文件/文件夹")
        return uniqueFiles
    }
    
    /// 验证是否为合法的删除目标，防止误删系统文件
    private func isValidDeletionTarget(_ url: URL) -> Bool {
        let path = url.path
        // 简单的安全检查：确保不删除根目录或主要系统目录
        if path == "/" || path == "/Applications" || path == "/System" || path == "/Library" {
            return false
        }
        // 确保在用户目录下
        if !path.contains("/Users/") {
            return false
        }
        return true
    }
}
