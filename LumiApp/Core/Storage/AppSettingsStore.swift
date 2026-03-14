import Foundation

/// 基于数据库目录的键值存储，替代 UserDefaults，所有数据存放在 getDBFolderURL()/app_settings 下
final class AppSettingsStore: @unchecked Sendable {
    static let shared = AppSettingsStore()

    private let directory: URL
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "AppSettingsStore.queue", qos: .userInitiated)

    private init() {
        self.directory = AppConfig.getDBFolderURL().appendingPathComponent("app_settings", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /// 将 key 转为安全文件名（仅保留字母数字与下划线）
    private func fileURL(forKey key: String) -> URL {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        let name = safe.isEmpty ? "key" : safe
        return directory.appendingPathComponent("\(name).plist")
    }

    // MARK: - Write

    func set(_ value: Any?, forKey key: String) {
        queue.sync {
            let url = self.fileURL(forKey: key)
            if let value = value {
                let plist: Any
                if let data = value as? Data {
                    plist = ["_data": data]
                } else if let string = value as? String {
                    plist = string
                } else if let number = value as? Int {
                    plist = number
                } else if let number = value as? Double {
                    plist = number
                } else if let flag = value as? Bool {
                    plist = flag
                } else if let date = value as? Date {
                    plist = date
                } else if let arr = value as? [String] {
                    plist = arr
                } else if let dict = value as? [String: Bool] {
                    plist = dict
                } else {
                    return
                }
                try? PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0).write(to: url)
            } else {
                try? self.fileManager.removeItem(at: url)
            }
        }
    }

    func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    // MARK: - Read (synchronous, call from main or init)

    func object(forKey key: String) -> Any? {
        queue.sync {
            let url = fileURL(forKey: key)
            guard fileManager.fileExists(atPath: url.path),
                  let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
                return nil
            }
            if let dict = plist as? [String: Any], let dataVal = dict["_data"] as? Data {
                return dataVal
            }
            return plist
        }
    }

    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    func data(forKey key: String) -> Data? {
        object(forKey: key) as? Data
    }

    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    func array(forKey key: String) -> [Any]? {
        object(forKey: key) as? [Any]
    }
}
