import Foundation

/// 自动批准设置的持久化存储（按项目隔离）
final class AgentAutoApprovePersistenceStore {
    private let fileManager = FileManager.default
    private let fileURL: URL

    private static let fileName = "auto_approve_states.plist"

    init() {
        let settingsDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("AgentAutoApproveHeader", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.fileURL = settingsDir.appendingPathComponent(Self.fileName)
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)
    }

    /// 加载指定项目的自动批准设置
    /// - Parameter projectPath: 项目路径
    /// - Returns: 设置值，nil 表示没有保存过
    func loadEnabled(for projectPath: String) -> Bool? {
        let dict = readDict()
        return dict[key(for: projectPath)] as? Bool
    }

    /// 保存指定项目的自动批准设置
    /// - Parameters:
    ///   - enabled: 是否启用
    ///   - projectPath: 项目路径
    func saveEnabled(_ enabled: Bool, for projectPath: String) {
        var dict = readDict()
        dict[key(for: projectPath)] = enabled
        writeDict(dict)
    }

    // MARK: - Private

    private func key(for projectPath: String) -> String {
        // 使用项目路径的哈希作为 key，避免路径中的特殊字符问题
        return projectPath.data(using: .utf8)?
            .base64EncodedString() ?? projectPath
    }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }
        let tmp = fileURL.deletingLastPathComponent().appendingPathComponent("auto_approve_states.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
        }
    }
}