import Foundation
import CryptoKit

/// 项目文件树状态管理器
/// 负责持久化保存和恢复文件树的展开/折叠状态
final class FileTreeStateManager: @unchecked Sendable {
    static let shared = FileTreeStateManager()
    
    private let userDefaults: UserDefaults
    private let expandedKeyPrefix = "com.cofficlab.lumi.fileTree.expanded."
    
    private init() {
        self.userDefaults = UserDefaults.standard
    }
    
    /// 获取项目特定的状态键前缀
    /// 使用 SHA256 哈希确保跨应用启动的稳定性
    private func projectKeyPrefix(for projectPath: String) -> String {
        // 使用 SHA256 生成稳定的哈希值（hashValue 在不同启动间不稳定）
        let inputData = Data(projectPath.utf8)
        let hash = SHA256.hash(data: inputData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        // 取前 16 个字符作为项目标识
        let projectIdentifier = String(hashString.prefix(16))
        return "\(expandedKeyPrefix)\(projectIdentifier)."
    }
    
    /// 检查某个目录是否应该展开
    func isExpanded(url: URL, projectPath: String) -> Bool {
        let key = expandedKey(for: url, projectPath: projectPath)
        return userDefaults.bool(forKey: key)
    }
    
    /// 设置目录的展开状态
    func setExpanded(_ expanded: Bool, url: URL, projectPath: String) {
        let key = expandedKey(for: url, projectPath: projectPath)
        userDefaults.set(expanded, forKey: key)
    }
    
    /// 清除项目的所有展开状态（用于项目切换或重置）
    func clearState(for projectPath: String) {
        let prefix = projectKeyPrefix(for: projectPath)
        
        // 获取所有键
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // 过滤出当前项目的键并删除
        for key in allKeys {
            if key.hasPrefix(prefix) {
                userDefaults.removeObject(forKey: key)
            }
        }
    }
    
    /// 生成存储键
    private func expandedKey(for url: URL, projectPath: String) -> String {
        let prefix = projectKeyPrefix(for: projectPath)
        // 使用相对于项目根目录的路径作为标识
        // 确保路径规范化：移除末尾的斜杠，确保一致性
        let normalizedProjectPath = projectPath.hasSuffix("/") 
            ? String(projectPath.dropLast()) 
            : projectPath
        
        var relativePath = url.path
        if relativePath.hasPrefix(normalizedProjectPath) {
            relativePath = String(relativePath.dropFirst(normalizedProjectPath.count))
        }
        
        // 确保相对路径以 / 开头但不是空字符串
        if relativePath.isEmpty {
            relativePath = "/"
        } else if !relativePath.hasPrefix("/") {
            relativePath = "/" + relativePath
        }
        
        return "\(prefix)\(relativePath)"
    }
}
