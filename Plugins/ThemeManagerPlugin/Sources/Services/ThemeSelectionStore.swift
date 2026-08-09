import Foundation
import os

/// Persisted store for the user's selected UI theme.
///
/// Saves/loads `selectedThemeID` to `<pluginDataDirectory>/theme-selection.plist`.
/// Writes are performed off the main thread via `Task.detached`.
///
/// Storage follows the project-wide convention enforced by `StoragePlugin` /
/// `StorageService.pluginDataDirectory(for:)`, which resolves to
/// `<Application Support>/<bundleID>/db_<debug|production>_v<major>/<PluginName>/`.
/// Callers are expected to obtain the directory from
/// `kernel.storage.pluginDataDirectory(for: "ThemeManager")` and inject it
/// during `onBoot`; when no directory is injected we fall back to a path that
/// matches the same convention (so we never silently write to an unrelated
/// location such as `<Application Support>/LumiUI/...`).
@MainActor
final class ThemeSelectionStore: ObservableObject {
    /// Shared instance for environments where no injection is possible
    /// (e.g. SwiftUI previews, ad-hoc tests). The directory is resolved lazily
    /// using the same `db_<mode>_v<major>/ThemeManager` convention as the
    /// injected path, so production builds never end up writing to the
    /// legacy `<Application Support>/LumiUI/...` location.
    static let shared = ThemeSelectionStore()

    /// Default plugin name used by the `StorageService` convention. Keep this
    /// in sync with `StorageService.pluginDataDirectory(for:)` callers in this
    /// plugin (`ThemeManagerPlugin.onBoot`).
    static let pluginName = "ThemeManager"

    @Published var selectedThemeID: String?

    private let storageURL: URL
    private let log = Logger(subsystem: "com.coffic.lumi", category: "theme-selection")

    /// Designated initializer.
    ///
    /// - Parameter pluginDataDirectory: Directory to read/write
    ///   `theme-selection.plist` in. Pass the result of
    ///   `kernel.storage.pluginDataDirectory(for: ThemeSelectionStore.pluginName)`
    ///   for production builds. When `nil` is supplied (e.g. SwiftUI previews
    ///   or legacy callers), the store falls back to a path matching the
    ///   `StoragePlugin` convention so behaviour stays consistent.
    @usableFromInline
    init(pluginDataDirectory: URL? = nil) {
        let resolved = pluginDataDirectory ?? Self.defaultPluginDataDirectory
        self.storageURL = resolved.appendingPathComponent("theme-selection.plist", isDirectory: false)

        load()
    }

    /// Save the selected theme ID to disk (off-main-thread).
    func save(selectedThemeID: String) {
        self.selectedThemeID = selectedThemeID
        let url = storageURL
        let themeID = selectedThemeID
        Task.detached(priority: .utility) { [weak self] in
            do {
                let directory = url.deletingLastPathComponent()
                if !FileManager.default.fileExists(atPath: directory.path) {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                let plist = ["selectedThemeID": themeID]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: url, options: .atomic)
            } catch {
                self?.log.error("Failed to save theme selection: \(error)")
            }
        }
    }

    /// Load the saved theme ID from disk.
    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: storageURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            if let dict = plist as? [String: String],
               let themeID = dict["selectedThemeID"] {
                selectedThemeID = themeID
            }
        } catch {
            log.error("Failed to load theme selection: \(error)")
        }
    }

    // MARK: - Default directory resolution

    /// Mirrors `StorageService.makeDefaultDataRootDirectory()` in spirit but
    /// without depending on `StoragePlugin` (so this file remains free of the
    /// `LumiKernel` import). Resolves to:
    ///
    ///     <Application Support>/<bundleID>/db_<debug|production>_v<major>/ThemeManager
    private static var defaultPluginDataDirectory: URL {
        let dataRoot = defaultDataRootDirectory
            .appendingPathComponent(Self.pluginName, isDirectory: true)
        return dataRoot
    }

    private static var defaultDataRootDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4"
        let majorVersion = version.split(separator: ".").first.flatMap { Int($0) } ?? 4
        #if DEBUG
        let dbDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let dbDirectoryName = "db_production_v\(majorVersion)"
        #endif
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(dbDirectoryName, isDirectory: true)
    }
}