import Foundation
import MagicKit

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
    private func projectKeyPrefix(for projectPath: String) -> String {
        // 使用项目路径的哈希值来区分不同项目
        let projectHash = projectPath.hashValue
        return "\(expandedKeyPrefix)\(projectHash)."
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
        let relativePath = url.path.replacingOccurrences(of: projectPath, with: "")
        return "\(prefix)\(relativePath)"
    }
}
