import Foundation

/// DebugBar 自包含状态存储（不依赖 `PluginStateStore`）。
enum DebugBarStateStore {
    private static let pluginDirName = "DebugBar"
    private static let settingsFileName = "debugbar_state.plist"
    private static let tmpFileName = "debugbar_state.tmp"

    private static let settingsDirURL: URL = {
        AppConfig.getDBFolderURL()
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(pluginDirName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }()

    private static func settingsFileURL() -> URL {
        settingsDirURL.appendingPathComponent(settingsFileName, isDirectory: false)
    }

    static func loadString(forKey key: String) -> String? {
        let fileURL = settingsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }
        return dict[key] as? String
    }

    static func saveString(_ value: String, forKey key: String) {
        var dict: [String: Any] = [:]
        let fileURL = settingsFileURL()

        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let existing = plist as? [String: Any] {
            dict = existing
        }

        dict[key] = value

        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }

        do {
            try FileManager.default.createDirectory(at: settingsDirURL, withIntermediateDirectories: true, attributes: nil)

            let tmpURL = settingsDirURL.appendingPathComponent(tmpFileName, isDirectory: false)
            try data.write(to: tmpURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try FileManager.default.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            // 不影响 UI 展示：仅用于 Debug 预览尺寸记忆。
        }
    }
}

