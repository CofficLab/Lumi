import Foundation

/// 插件设置持久化存储，遵循 Projects 插件的数据存储约定：
/// 所有数据存放在 `<pluginDataDir>/settings/` 目录下的 JSON 文件中。
final class ActivityHeatmapSettingsStore {
    private let settingsDirectory: URL

    // MARK: - File Names

    private nonisolated(unsafe) static let settingsDirectoryName = "settings"
    private nonisolated(unsafe) static let settingsFileName = "settings.json"

    // MARK: - Model

    struct Settings: Codable {
        var selectedPeriodRawValue: Int?
    }

    // MARK: - Init

    init(pluginDirectory: URL?) {
        let directory = pluginDirectory ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("Lumi/ActivityHeatmap")
        self.settingsDirectory = directory
            .appendingPathComponent(Self.settingsDirectoryName, isDirectory: true)
    }

    // MARK: - Load

    func loadSettings() -> Settings {
        let url = settingsDirectory.appendingPathComponent(Self.settingsFileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Settings()
        }
        return settings
    }

    // MARK: - Save

    func saveSettings(_ settings: Settings) {
        try? FileManager.default.createDirectory(
            at: settingsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let url = settingsDirectory.appendingPathComponent(Self.settingsFileName, isDirectory: false)
        Self.write(settings, to: url)
    }

    // MARK: - Write Helper

    private nonisolated static func write<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let tmpURL = url.appendingPathExtension("tmp")
        do {
            try data.write(to: tmpURL, options: .atomic)
            try FileManager.default.replaceItemAt(url, withItemAt: tmpURL)
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
        }
    }
}
