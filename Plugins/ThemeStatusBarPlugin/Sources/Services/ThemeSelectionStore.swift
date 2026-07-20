import Foundation
import os

/// Persisted store for the user's selected UI theme.
///
/// Saves/loads `selectedThemeID` to `<pluginDataDirectory>/LumiUI/theme-selection.plist`.
/// Writes are performed off the main thread via `Task.detached`.
@MainActor
final class ThemeSelectionStore: ObservableObject {
    static let shared = ThemeSelectionStore()

    @Published var selectedThemeID: String?

    private let storageURL: URL
    private let log = Logger(subsystem: "com.coffic.lumi", category: "theme-selection")

    init(pluginDataDirectory: URL? = nil) {
        let baseDir = pluginDataDirectory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.storageURL = baseDir.appendingPathComponent("LumiUI/theme-selection.plist", isDirectory: false)

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
}
