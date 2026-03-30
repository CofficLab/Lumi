import Foundation

/// 持久化每个项目最后一次选中的文件路径。
final class FileTreeSelectionStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "FileTreeSelectionStore.queue", qos: .userInitiated)
    private let fileManager = FileManager.default

    private static let pluginDirName = "AgentFileTreeNative"
    private static let settingsFileName = "selection_state.plist"
    private static let tmpFileName = "selection_state.tmp"

    private var settingsDirURL: URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }

    private var settingsFileURL: URL {
        settingsDirURL.appendingPathComponent(Self.settingsFileName, isDirectory: false)
    }

    func loadSelectionPath(forProjectPath projectPath: String) -> String? {
        queue.sync {
            let dict = readDict()
            return dict[projectPath] as? String
        }
    }

    func saveSelectionPath(_ filePath: String, forProjectPath projectPath: String) {
        queue.sync {
            var dict = readDict()
            dict[projectPath] = filePath
            writeDict(dict)
        }
    }

    func removeSelection(forProjectPath projectPath: String) {
        queue.sync {
            var dict = readDict()
            dict.removeValue(forKey: projectPath)
            writeDict(dict)
        }
    }

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
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }

        do {
            try fileManager.createDirectory(at: settingsDirURL, withIntermediateDirectories: true, attributes: nil)

            let tmpURL = settingsDirURL.appendingPathComponent(Self.tmpFileName, isDirectory: false)
            try data.write(to: tmpURL, options: .atomic)

            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            // 持久化失败不阻塞主流程。
        }
    }
}
