import Foundation
import os
import SuperLogKit

/// ConversationList Plugin 本地存储
///
/// 负责持久化插件的配置和设置项。
/// 存储位置：ConversationListContext.databaseDirectory()/ConversationListPlugin/settings.plist
public final class ConversationListLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.conversation-list.local-store")
    
    // MARK: - Singleton
    
    public static let shared = ConversationListLocalStore()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ConversationListLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL
    
    private static let storageKey = "selectedConversationId"
    private static let legacyKey: String = {
        #if DEBUG
        return "Conversation_SelectedId_Debug"
        #else
        return "Conversation_SelectedId"
        #endif
    }()
    
    // MARK: - Initialization
    
    public convenience init() {
        self.init(databaseDirectory: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
    }

    public convenience init(databaseDirectory: URL) {
        self.init(settingsDirectory: databaseDirectory
            .appendingPathComponent("ConversationListPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true))
    }

    init(settingsDirectory root: URL) {
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("conversation_selection.plist")
        self.corruptSettingsFileURL = root.appendingPathComponent("conversation_selection.corrupt.plist")
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create conversation selection directory failed: \(error.localizedDescription)")
        }
        migrateLegacyIfNeeded()
    }
    
    // MARK: - Public API
    
    /// 加载选中的会话 ID
    public func loadSelectedConversationId() -> UUID? {
        queue.sync {
            guard let idString = readDict()[Self.storageKey] as? String else { return nil }
            return UUID(uuidString: idString)
        }
    }
    
    /// 保存选中的会话 ID
    @discardableResult
    public func saveSelectedConversationId(_ id: UUID?) -> Bool {
        queue.sync {
            var dict = readDict()
            if let id {
                dict[Self.storageKey] = id.uuidString
            } else {
                dict.removeValue(forKey: Self.storageKey)
            }
            return writeDict(dict)
        }
    }
    
    // MARK: - Private Helpers
    
    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read conversation selection failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read conversation selection failed: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }
    
    /// 写入字典到文件（原子操作）
    @discardableResult
    private func writeDict(_ dict: [String: Any]) -> Bool {
        let data: Data
        do {
            data = try PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .binary,
                options: 0
            )
        } catch {
            Self.logger.error("\(self.t)Encode conversation selection failed: \(error.localizedDescription)")
            return false
        }
        
        let tmpURL = pluginDirectory.appendingPathComponent("conversation_selection.tmp")
        
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
            try data.write(to: tmpURL, options: .atomic)
            
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist conversation selection failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmpURL)
            return false
        }
    }

    private func quarantineCorruptSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            Self.logger.error("\(self.t)Quarantine corrupt conversation selection failed: \(error.localizedDescription)")
        }
    }
    
    /// 迁移旧版本数据
    private func migrateLegacyIfNeeded() {
        queue.sync {
            guard readDict()[Self.storageKey] == nil else { return }
            
            let legacyFile = pluginDirectory
                .deletingLastPathComponent()
                .deletingLastPathComponent()
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
