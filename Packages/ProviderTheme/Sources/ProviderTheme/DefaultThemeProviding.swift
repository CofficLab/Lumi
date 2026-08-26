import Foundation

/// `ThemeProviding` 的默认实现：持有主题注册表与选中状态，并持久化
/// 用户选中的主题 id。
///
/// 复刻旧版 Lumi `ThemeManagerPlugin` 的 `ThemeManager` + `ThemeSelectionStore`：
/// - 主题贡献收集：`registerTheme` / `unregisterTheme` / `replaceAllThemes`
/// - 选中与切换：`selectTheme(id:)`（未知 id 抛错）
/// - 持久化：`<数据根目录>/ThemeManager/theme-selection.plist`，写盘在主线程外执行
///
/// 消费方（设置项、菜单）直接订阅本 Provider 的 `objectWillChange`，即可感知
/// 主题列表与选中状态变化；KernelCore 不参与状态转发。
@MainActor
public final class DefaultThemeProviding: ThemeProviding {
    /// 数据目录名，与旧版 Lumi 的 ThemeManager 保持一致语义。
    public static let pluginName = "ThemeManager"

    @Published public private(set) var themes: [LumiTheme] = []
    @Published public private(set) var selectedThemeId: String?

    /// 当前选中主题。
    public var selectedTheme: LumiTheme? {
        guard let selectedThemeId else { return nil }
        return themeItems[selectedThemeId]
    }

    /// 主题注册表：id → 主题。
    private var themeItems: [String: LumiTheme] = [:]

    /// 选中主题持久化文件。
    private var storageURL: URL

    /// - Parameters:
    ///   - storageDirectory: 持久化目录（存放 `theme-selection.plist`）。
    ///     传入 `StorageProviding.pluginDataDirectory(for: "ThemeManager")`
    ///     以遵循 Storage 约定；为 `nil` 时回退到
    ///     `<Application Support>/<bundleID>/ThemeManager/`。
    ///   - builtinThemes: 初始化时预注册的主题；默认注册全部内置主题。
    public init(
        storageDirectory: URL? = nil,
        builtinThemes: [LumiTheme] = BuiltinThemes.all
    ) {
        let resolved = storageDirectory ?? Self.defaultStorageDirectory
        self.storageURL = resolved.appendingPathComponent("theme-selection.plist", isDirectory: false)

        for theme in builtinThemes {
            registerThemeInternal(theme)
        }
        restorePersistedSelection()
    }

    // MARK: - ThemeProviding

    public func selectTheme(id: String) throws {
        guard themeItems[id] != nil else {
            throw ThemeProvidingError.unknownThemeId(id)
        }
        guard selectedThemeId != id else { return }
        selectedThemeId = id
        saveSelection()
    }

    public func registerTheme(_ theme: LumiTheme) {
        registerThemeInternal(theme)
    }

    public func unregisterTheme(id: String) {
        guard themeItems.removeValue(forKey: id) != nil else { return }
        updateSortedThemes()
        if selectedThemeId == id {
            // 注销的是当前选中：回退到剩余第一个，并持久化新选中。
            selectedThemeId = themes.first?.id
            saveSelection()
        }
    }

    public func replaceAllThemes(_ themes: [LumiTheme]) throws {
        guard !themes.isEmpty else {
            throw ThemeProvidingError.noThemesRegistered
        }
        var seen = Set<String>()
        for theme in themes {
            guard !seen.contains(theme.id) else {
                throw ThemeProvidingError.duplicateThemeId(theme.id)
            }
            seen.insert(theme.id)
        }

        let previousSelected = selectedThemeId
        themeItems = Dictionary(uniqueKeysWithValues: themes.map { ($0.id, $0) })
        updateSortedThemes()

        // 尽量保持选中：原选中 → 持久化偏好 → 第一个主题。
        if let previousSelected, themeItems[previousSelected] != nil {
            selectedThemeId = previousSelected
            return
        }
        if let persisted = Self.loadSelectedThemeID(from: storageURL),
           themeItems[persisted] != nil {
            selectedThemeId = persisted
            return
        }
        selectedThemeId = self.themes.first?.id
    }

    // MARK: - Storage Injection

    /// 注入持久化目录（在注册后、任何 `selectTheme` 之前调用）。
    ///
    /// 用于遵循 `StorageProviding.pluginDataDirectory(for: "ThemeManager")`
    /// 约定：宿主先以默认目录构造，再注入 Storage 提供的目录并恢复已存偏好。
    public func setStorageDirectory(_ directory: URL) {
        storageURL = directory.appendingPathComponent("theme-selection.plist", isDirectory: false)
        restorePersistedSelection()
    }

    // MARK: - Private

    private func registerThemeInternal(_ theme: LumiTheme) {
        themeItems[theme.id] = theme
        updateSortedThemes()
    }

    private func updateSortedThemes() {
        themes = themeItems.values.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// 恢复持久化的选中主题（存在且已注册时），否则选中列表第一个。
    private func restorePersistedSelection() {
        guard let savedID = Self.loadSelectedThemeID(from: storageURL),
              themeItems[savedID] != nil else {
            selectedThemeId = themes.first?.id
            return
        }
        selectedThemeId = savedID
    }

    /// 将当前选中主题 id 写盘（主线程外执行）。
    private func saveSelection() {
        let url = storageURL
        let themeID = selectedThemeId
        Task.detached(priority: .utility) {
            do {
                let directory = url.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let plist: [String: String]
                if let themeID {
                    plist = ["selectedThemeID": themeID]
                } else {
                    plist = [:]
                }
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: url, options: .atomic)
            } catch {
                // 持久化失败不阻断主题切换。
            }
        }
    }

    // MARK: - Default directory resolution

    /// 默认持久化目录：`<Application Support>/<bundleID>/ThemeManager/`。
    private static var defaultStorageDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        return base
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(Self.pluginName, isDirectory: true)
    }

    /// 读取持久化的选中主题 id；文件缺失或损坏时返回 `nil`。
    private static func loadSelectedThemeID(from url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: String] else {
            return nil
        }
        return dict["selectedThemeID"]
    }
}
