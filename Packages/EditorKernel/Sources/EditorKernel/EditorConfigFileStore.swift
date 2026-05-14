import Foundation

public struct EditorConfigFileStore: Sendable {
    public let settingsDirectoryURL: URL
    public let settingsFileName: String
    public let temporaryFileName: String

    public init(
        settingsDirectoryURL: URL,
        settingsFileName: String = "editor_config.plist",
        temporaryFileName: String = "editor_config.tmp"
    ) {
        self.settingsDirectoryURL = settingsDirectoryURL
        self.settingsFileName = settingsFileName
        self.temporaryFileName = temporaryFileName
    }

    public func settingsFileURL() -> URL {
        settingsDirectoryURL.appendingPathComponent(settingsFileName, isDirectory: false)
    }

    public func loadDict(fileManager: FileManager = .default) -> [String: Any] {
        let fileURL = settingsFileURL()
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    public func saveDict(_ dict: [String: Any], fileManager: FileManager = .default) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else { return }

        do {
            try fileManager.createDirectory(at: settingsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            let tmpURL = settingsDirectoryURL.appendingPathComponent(temporaryFileName, isDirectory: false)
            try data.write(to: tmpURL, options: .atomic)
            let fileURL = settingsFileURL()
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            // Persistence failures should not break the editor workflow.
        }
    }

    public func loadingValue<T>(forKey key: String, as type: T.Type = T.self) -> T? {
        loadDict()[key] as? T
    }

    public func savingValue(_ value: Any, forKey key: String) {
        var dict = loadDict()
        dict[key] = value
        saveDict(dict)
    }

    public func removingValue(forKey key: String) {
        var dict = loadDict()
        dict.removeValue(forKey: key)
        saveDict(dict)
    }
}
