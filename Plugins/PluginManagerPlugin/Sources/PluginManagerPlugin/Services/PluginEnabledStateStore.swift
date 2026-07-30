import Foundation
import LumiKernel

/// Persists plugin enablement overrides inside PluginManagerPlugin's own data directory.
@MainActor
final class PluginEnabledStateStore: PluginEnabledStatePersistence {
    private static let filename = "plugin-enabled-overrides.plist"
    private static let legacyDefaultsKey = "com.coffic.lumi.pluginEnabledOverrides"

    private let fileURL: URL
    private var overrides: [String: Bool]

    init(pluginDirectory: URL) {
        self.fileURL = pluginDirectory.appendingPathComponent(Self.filename, isDirectory: false)
        self.overrides = Self.load(from: fileURL)

        // Preserve users' existing settings from the old kernel-owned UserDefaults store.
        if overrides.isEmpty,
           let legacy = UserDefaults.standard.dictionary(forKey: Self.legacyDefaultsKey) as? [String: Bool],
           !legacy.isEmpty {
            self.overrides = legacy
            persist()
            UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
        }
    }

    func loadPluginEnabledOverrides() -> [String: Bool] {
        overrides
    }

    func savePluginEnabledOverride(_ enabled: Bool, for pluginID: String) {
        overrides[pluginID] = enabled
        persist()
    }

    func clearPluginEnabledOverride(for pluginID: String) {
        overrides.removeValue(forKey: pluginID)
        persist()
    }

    private func persist() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(
                fromPropertyList: overrides,
                format: .binary,
                options: 0
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // A failed write must not prevent the in-memory setting from taking effect.
        }
    }

    private static func load(from url: URL) -> [String: Bool] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let values = plist as? [String: Bool] else {
            return [:]
        }
        return values
    }
}
