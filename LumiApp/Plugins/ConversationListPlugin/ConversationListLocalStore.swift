import Foundation

/// ConversationList Plugin 本地存储
///
/// 负责持久化插件的配置和设置项。
/// 存储位置：AppConfig.getDBFolderURL()/ConversationListPlugin/settings.plist
final class ConversationListLocalStore: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = ConversationListLocalStore()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ConversationListLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    
    private static let storageKey = "selectedConversationId"
    private static let legacyKey: String = {
        #if DEBUG
        return "Conversation_SelectedId_Debug"
        #else
        return "Conversation_SelectedId"
        #endif
    }()
    
    // MARK: - Initialization
    
    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("ConversationListPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("conversation_selection.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        migrateLegacyIfNeeded()
    }
    
    // MARK: - Public API
    
    /// 加载选中的会话 ID
    func loadSelectedConversationId() -> UUID? {
        queue.sync {
            guard let idString = readDict()[Self.storageKey] as? String else { return nil }
            return UUID(uuidString: idString)
        }
    }
    
    /// 保存选中的会话 ID
    func saveSelectedConversationId(_ id: UUID?) {
        queue.sync {
            var dict = readDict()
            if let id {
                dict[Self.storageKey] = id.uuidString
            } else {
                dict.removeValue(forKey: Self.storageKey)
            }
            writeDict(dict)
        }
    }
    
    // MARK: - Private Helpers
    
    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    /// 写入字典到文件（原子操作）
    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }
        
        let tmpURL = pluginDirectory.appendingPathComponent("conversation_selection.tmp")
        
        do {
            // 原子写入临时文件
            try data.write(to: tmpURL, options: .atomic)
            
            // 替换原文件
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
    
    /// 迁移旧版本数据
    private func migrateLegacyIfNeeded() {
        queue.sync {
            guard readDict()[Self.storageKey] == nil else { return }
            
            let legacyFile = AppConfig.getDBFolderURL()
                .appendingPathComponent("app_settings", isDirectory: true)
                .appendingPathComponent(sanitizeLegacyKey(Self.legacyKey) + ".plist")
            
            guard fileManager.fileExists(atPath: legacyFile.path),
                  let data = try? Data(contentsOf: legacyFile),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let legacyValue = plist as? String,
                  let uuid = UUID(uuidString: legacyValue) else {
                return
            }
            
            var dict = readDict()
            dict[Self.storageKey] = uuid.uuidString
            writeDict(dict)
        }
    }
    
    /// 清理遗留键名中的特殊字符
    private func sanitizeLegacyKey(_ key: String) -> String {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        return safe.isEmpty ? "key" : safe
    }
}
