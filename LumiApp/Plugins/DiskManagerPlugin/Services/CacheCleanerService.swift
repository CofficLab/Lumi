import Foundation
import AppKit
import OSLog
import MagicKit

@MainActor
class CacheCleanerService: ObservableObject, SuperLog {
    static let shared = CacheCleanerService()

    @Published var categories: [CacheCategory] = []
    @Published var isScanning = false
    @Published var scanProgress: String = ""

    // MARK: - 预定义扫描规则
    
    // 使用闭包来延迟获取路径（因为 homeDirectory 可能会变，虽然不太可能）
    private var scanRules: [(CacheCategory.SafetyLevel, String, String, String, String, [String])] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            // level, id, name, desc, icon, paths
            (.safe, "user_app_cache", "应用缓存", "清理应用程序产生的临时文件", "app.badge", ["\(home)/Library/Caches"]),
            (.safe, "browser_cache", "浏览器缓存", "清理 Chrome, Safari, Firefox 等浏览器缓存", "safari", [
                "\(home)/Library/Caches/Google/Chrome",
                "\(home)/Library/Caches/com.apple.Safari",
                "\(home)/Library/Caches/Firefox"
            ]),
            (.safe, "dev_cache", "开发工具缓存", "清理 Xcode DerivedData, Archives 及包管理器缓存", "hammer", [
                "\(home)/Library/Developer/Xcode/DerivedData",
                "\(home)/Library/Developer/Xcode/Archives",
                "\(home)/.npm/_cacache",
                "\(home)/.cargo/registry"
            ]),
            (.medium, "system_logs", "系统日志", "清理系统运行日志文件", "doc.text", [
                "\(home)/Library/Logs"
            ]),
            (.safe, "trash", "废纸篓", "清空废纸篓中的文件", "trash", [
                "\(home)/.Trash"
            ])
        ]
    }

    // MARK: - Public API

    func scanCaches() async {
        isScanning = true
        scanProgress = "正在初始化..."
        var results: [CacheCategory] = []
        
        // 并行扫描各个类别
        await withTaskGroup(of: CacheCategory?.self) { group in
            for (level, id, name, desc, icon, paths) in scanRules {
                group.addTask {
                    await self.scanCategory(id: id, name: name, desc: desc, icon: icon, paths: paths, level: level)
                }
            }
            
            for await category in group {
                if let category = category {
                    results.append(category)
                }
            }
        }
        
        self.categories = results.sorted { $0.safetyLevel < $1.safetyLevel }
        self.isScanning = false
        self.scanProgress = ""
    }
    
    func cleanup(paths: [CachePath]) async throws -> Int64 {
        var freedSpace: Int64 = 0
        
        for item in paths {
            do {
                try FileManager.default.removeItem(atPath: item.path)
                freedSpace += item.size
            } catch {
                os_log(.error, "\(self.t)清理失败: \(item.path) - \(error.localizedDescription)")
            }
        }
        
        // 重新扫描以更新状态
        await scanCaches()
        return freedSpace
    }

    // MARK: - Private Implementation
    
    private func scanCategory(id: String, name: String, desc: String, icon: String, paths: [String], level: CacheCategory.SafetyLevel) async -> CacheCategory? {
        var cachePaths: [CachePath] = []
        
        for path in paths {
            // Update progress (Note: on main actor, might cause stutter if too frequent, but acceptable here)
            await MainActor.run {
                self.scanProgress = "正在扫描 \(name)..."
            }
            
            if let info = await getPathInfo(path) {
                // 特殊处理：如果是 ~/Library/Caches，我们不想删除整个文件夹，而是列出子文件夹
                if path.hasSuffix("/Library/Caches") {
                    let subPaths = await scanSubDirectories(at: path)
                    cachePaths.append(contentsOf: subPaths)
                } else {
                    cachePaths.append(CachePath(
                        path: path,
                        name: URL(fileURLWithPath: path).lastPathComponent,
                        description: path,
                        size: info.size,
                        fileCount: info.count,
                        canDelete: true,
                        icon: NSWorkspace.shared.icon(forFile: path)
                    ))
                }
            }
        }
        
        if cachePaths.isEmpty {
            return nil
        }
        
        return CacheCategory(
            id: id,
            name: name,
            description: desc,
            icon: icon,
            paths: cachePaths,
            safetyLevel: level
        )
    }
    
    private func scanSubDirectories(at path: String) async -> [CachePath] {
        let url = URL(fileURLWithPath: path)
        var results: [CachePath] = []
        
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else {
            return []
        }
        
        for content in contents {
            if let info = await getPathInfo(content.path), info.size > 0 {
                results.append(CachePath(
                    path: content.path,
                    name: content.lastPathComponent,
                    description: "应用缓存",
                    size: info.size,
                    fileCount: info.count,
                    canDelete: true,
                    icon: NSWorkspace.shared.icon(forFile: content.path)
                ))
            }
        }
        
        return results.sorted { $0.size > $1.size }
    }
    
    private func getPathInfo(_ path: String) async -> (size: Int64, count: Int)? {
        let fileManager = FileManager.default
        var isDir: ObjCBool = false
        
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir) else {
            return nil
        }
        
        if !isDir.boolValue {
            // 单个文件
            if let attrs = try? fileManager.attributesOfItem(atPath: path),
               let size = attrs[.size] as? Int64 {
                return (size, 1)
            }
            return nil
        }
        
        // 目录：递归计算大小
        // 为了性能，这里不使用 DiskService 的全扫描，而是快速遍历
        // 或者复用 DiskService.scan 但不构建树？
        // 简单起见，使用 Enumerator
        
        return await Task.detached {
            var localSize: Int64 = 0
            var localCount = 0
            
            guard let enumerator = fileManager.enumerator(atPath: path) else { return nil }
            
            // FileManager.DirectoryEnumerator is not thread-safe and not Sendable,
            // but we are inside a detached Task with a local instance created on that thread (if fileManager is thread safe).
            // Actually FileManager.default is thread-safe.
            // However, makeIterator() availability in async context is the issue.
            // We can iterate using while loop with nextObject() which is the ObjC way and avoids Sequence conformance issues in async
            
            while let _ = enumerator.nextObject() {
                if let fileAttrs = enumerator.fileAttributes,
                   let fileSize = fileAttrs[.size] as? Int64 {
                    localSize += fileSize
                    localCount += 1
                }
            }
            return (localSize, localCount)
        }.value
    }
}
