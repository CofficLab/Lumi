import Foundation

/// 模型偏好设置本地存储
final class ModelPreferenceStore: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ModelPreferenceStore.queue", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL

    static let shared = ModelPreferenceStore()

    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("ModelPreference", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("preference.plist")
        try? fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
    }

    /// 设置值
    /// - Parameters:
    ///   - value: 要设置的值
    ///   - key: 键名
    func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeDict(dict)
        }
    }

    /// 获取值
    /// - Parameter key: 键名
    /// - Returns: 对应的值
    func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    /// 获取字符串
    /// - Parameter key: 键名
    /// - Returns: 字符串值
    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    /// 清空所有设置
    func clearAll() {
        queue.sync {
            writeDict([:])
        }
    }

    // MARK: - Private Helpers

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else {
            return
        }

        let tmp = settingsDirectory.appendingPathComponent("preference.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
        }
    }
}