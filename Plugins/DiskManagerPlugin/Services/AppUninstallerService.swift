import Foundation
import AppKit

class AppUninstallerService {
    static let shared = AppUninstallerService()
    
    private let fileManager = FileManager.default
    
    private let searchPaths = [
        "/Applications",
        "\(NSHomeDirectory())/Applications"
    ]
    
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
    
    func scanApps() async -> [ApplicationInfo] {
        var apps: [ApplicationInfo] = []
        
        await withTaskGroup(of: [ApplicationInfo].self) { group in
            for path in searchPaths {
                group.addTask {
                    return self.scanAppsInDirectory(path)
                }
            }
            
            for await result in group {
                apps.append(contentsOf: result)
            }
        }
        
        return apps.sorted { $0.size > $1.size }
    }
    
    private func scanAppsInDirectory(_ path: String) -> [ApplicationInfo] {
        var apps: [ApplicationInfo] = []
        guard let urls = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.isApplicationKey], options: .skipsHiddenFiles) else {
            return []
        }
        
        for url in urls {
            if url.pathExtension == "app" {
                if let bundle = Bundle(url: url),
                   let bundleId = bundle.bundleIdentifier {
                    
                    // 获取基本信息
                    let name = bundle.infoDictionary?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
                    let icon = NSWorkspace.shared.icon(forFile: url.path)
                    
                    // 计算大小 (简单计算，不做深度递归以免太慢，或者异步做)
                    // 这里为了响应速度，先只计算 .app 本身的大小
                    let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
                    // 注意：.app 是一个目录，fileSizeKey 可能不准确，通常需要递归计算。
                    // 为了演示，我们暂时使用一个快速估算或后续异步更新。
                    // 更好的方式是使用 fastFolderSize (Phase 1 里的逻辑)
                    
                    // 尝试获取最后访问时间
                    let lastAccessed = (try? url.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate)
                    
                    let app = ApplicationInfo(
                        name: name,
                        path: url.path,
                        bundleId: bundleId,
                        icon: icon,
                        size: size, // 暂时用 0 或简单大小，实际应该递归计算
                        lastAccessed: lastAccessed
                    )
                    apps.append(app)
                }
            }
        }
        return apps
    }
    
    // 真正的文件夹大小计算
    func calculateSize(for path: String) async -> Int64 {
        return await DiskService.shared.calculateSize(for: URL(fileURLWithPath: path))
    }
    
    func scanRelatedFiles(for app: ApplicationInfo) async -> [RelatedFile] {
        guard let bundleId = app.bundleId else { return [] }
        let home = NSHomeDirectory()
        var relatedFiles: [RelatedFile] = []
        
        // 1. 添加 App 本身
        let appSize = await calculateSize(for: app.path)
        relatedFiles.append(RelatedFile(path: app.path, size: appSize, type: .app))
        
        // 2. 扫描 Library
        await withTaskGroup(of: RelatedFile?.self) { group in
            for libSubPath in libraryPaths {
                let fullPath = "\(home)/\(libSubPath)"
                
                group.addTask {
                    // 策略 A: 精确匹配 Bundle ID
                    let candidatePath1 = "\(fullPath)/\(bundleId)"
                    if self.fileManager.fileExists(atPath: candidatePath1) {
                        let size = await self.calculateSize(for: candidatePath1)
                        return RelatedFile(path: candidatePath1, size: size, type: self.getType(from: libSubPath))
                    }
                    
                    // 策略 B: 匹配 App Name (主要针对 Application Support)
                    // 注意：这可能误判，需谨慎。这里仅对 Application Support 尝试，且要求名字完全一致
                    if libSubPath.contains("Application Support") {
                        let candidatePath2 = "\(fullPath)/\(app.name)"
                        if self.fileManager.fileExists(atPath: candidatePath2) {
                             // 进一步检查：如果该文件夹内有 Info.plist 且 bundleID 匹配，则确认。否则... 略过以防误删？
                             // 简单起见，Phase 4 暂时只做 Bundle ID 匹配，或者让用户人工确认
                        }
                    }
                    
                    // 策略 C: Preferences plist
                    if libSubPath.contains("Preferences") {
                        let plistPath = "\(fullPath)/\(bundleId).plist"
                        if self.fileManager.fileExists(atPath: plistPath) {
                            let size = await self.calculateSize(for: plistPath)
                            return RelatedFile(path: plistPath, size: size, type: .preferences)
                        }
                    }
                    
                    // 策略 D: Saved State
                    if libSubPath.contains("Saved Application State") {
                         let statePath = "\(fullPath)/\(bundleId).savedState"
                         if self.fileManager.fileExists(atPath: statePath) {
                             let size = await self.calculateSize(for: statePath)
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
    
    func deleteFiles(_ files: [RelatedFile]) async throws {
        for file in files {
            try fileManager.removeItem(atPath: file.path)
        }
    }
}
