import Foundation

/// 持久化每个项目文件树的展开目录集合（相对路径）。
final class FileTreeExpansionStore: @unchecked Sendable {
    private let queue = DispatchQueue(label: "FileTreeExpansionStore.queue", qos: .userInitiated)
    private let fileManager = FileManager.default

    private static let pluginDirName = "AgentFileTreeNative"
    private static let settingsFileName = "expansion_state.plist"
    private static let tmpFileName = "expansion_state.tmp"

    private var settingsDirURL: URL {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(Self.pluginDirName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }

    private var settingsFileURL: URL {
        settingsDirURL.appendingPathComponent(Self.settingsFileName, isDirectory: false)
    }

    func loadExpandedRelativePaths(forProjectPath projectPath: String) -> Set<String> {
        queue.sync {
            let dict = readDict()
            let values = dict[projectPath] as? [String] ?? []
            return Set(values)
        }
    }

    func saveExpandedRelativePaths(_ paths: Set<String>, forProjectPath projectPath: String) {
        queue.sync {
            var dict = readDict()
            dict[projectPath] = Array(paths).sorted()
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
            // 展开状态保存失败不影响主流程。
        }
    }
}
