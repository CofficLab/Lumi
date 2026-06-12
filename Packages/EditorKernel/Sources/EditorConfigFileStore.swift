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

    public func corruptSettingsFileURL() -> URL {
        let baseName = (settingsFileName as NSString).deletingPathExtension
        return settingsDirectoryURL.appendingPathComponent("\(baseName).corrupt.plist", isDirectory: false)
    }

    public func loadDict(fileManager: FileManager = .default) -> [String: Any] {
        let fileURL = settingsFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return [:]
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            return [:]
        }

        do {
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                quarantineCorruptSettings(fileManager: fileManager)
                return [:]
            }
            return dict
        } catch {
            quarantineCorruptSettings(fileManager: fileManager)
            return [:]
        }
    }

    public func saveDict(_ dict: [String: Any], fileManager: FileManager = .default) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else { return }

        do {
            try fileManager.createDirectory(at: settingsDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: settingsFileURL(), options: .atomic)
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

    private func quarantineCorruptSettings(fileManager: FileManager) {
        let sourceURL = settingsFileURL()
        let quarantineURL = corruptSettingsFileURL()
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: quarantineURL.path) {
                try fileManager.removeItem(at: quarantineURL)
            }
            try fileManager.moveItem(at: sourceURL, to: quarantineURL)
        } catch {
            // Persistence recovery should not break the editor workflow.
        }
    }
}
