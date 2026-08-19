import Foundation

/// 插件启用状态的持久化实现：写入旧版 `PluginManagerPlugin` 的同一数据目录。
///
/// 完美复刻旧版 `PluginEnabledStateStore`（Plugins/PluginManagerPlugin）：
/// - 文件路径：`<数据根目录>/PluginManager/plugin-enabled-overrides.plist`（与旧版一致，
///   数据仍保存在原来的目录，用户无需手动迁移）。
/// - 文件格式：binary plist，`[String: Bool]`。
/// - 迁移：首次初始化且文件为空时，从旧版内核持有的 UserDefaults key
///   `com.coffic.lumi.pluginEnabledOverrides` 迁移，成功后清除该 key。
@MainActor
public final class PluginEnabledStateStore {
    private static let filename = "plugin-enabled-overrides.plist"
    private static let legacyDefaultsKey = "com.coffic.lumi.pluginEnabledOverrides"

    private let fileURL: URL
    private var overrides: [String: Bool]

    public init(pluginDirectory: URL) {
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

    // MARK: - State Access

    public func enabledState(pluginID: String) -> Bool? {
        overrides[pluginID]
    }

    public func setEnabled(_ enabled: Bool, pluginID: String) {
        overrides[pluginID] = enabled
        persist()
    }

    public func removeState(pluginID: String) {
        overrides.removeValue(forKey: pluginID)
        persist()
    }

    // MARK: - Helpers

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
