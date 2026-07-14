import Foundation

@MainActor
public final class PluginSettingsStore {
    private let settingsURL: URL

    public convenience init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let directory = appSupport.appendingPathComponent("Lumi")
        self.init(directory: directory)
    }

    public init(directory: URL) {
        self.settingsURL = directory.appendingPathComponent("plugin-settings.plist")
    }

    public func loadEnabledOverrides() -> [String: Bool] {
        guard let data = try? Data(contentsOf: settingsURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Bool]
        else {
            return [:]
        }

        return dictionary
    }

    public func saveEnabledOverrides(_ overrides: [String: Bool]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: overrides,
            format: .xml,
            options: 0
        ) else {
            return
        }

        let settingsURL = self.settingsURL
        Task.detached(priority: .utility) {
            do {
                try FileManager.default.createDirectory(
                    at: settingsURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: settingsURL, options: .atomic)
            } catch {
                assertionFailure("Failed to save plugin settings: \(error)")
            }
        }
    }
}
