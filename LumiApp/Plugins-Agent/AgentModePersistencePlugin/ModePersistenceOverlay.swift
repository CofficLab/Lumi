import SwiftUI

struct ModePersistenceOverlay<Content: View>: View {
    @EnvironmentObject private var app: GlobalVM
    @Environment(\.windowState) private var windowState

    let content: Content
    private let store = AgentModePersistenceStore()

    @State private var restored = false

    var body: some View {
        content
            .onAppear {
                restoreIfNeeded()
            }
            .onChange(of: app.selectedMode) { _, newValue in
                store.saveMode(newValue)
            }
    }

    private func restoreIfNeeded() {
        guard !restored else { return }
        restored = true

        guard let saved = store.loadMode() else { return }
        app.selectedMode = saved
        windowState?.selectedMode = saved
    }
}

private final class AgentModePersistenceStore {
    private let fileManager = FileManager.default
    private let fileURL: URL

    private static let key = "selectedMode"
    private static let legacyKey = "App_SelectedMode"

    init() {
        let settingsDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("AgentModePersistencePlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.fileURL = settingsDir.appendingPathComponent("mode_state.plist")
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        migrateLegacyIfNeeded()
    }

    func loadMode() -> AppMode? {
        guard let raw = readDict()[Self.key] as? String else { return nil }
        return AppMode(rawValue: raw)
    }

    func saveMode(_ mode: AppMode) {
        var dict = readDict()
        dict[Self.key] = mode.rawValue
        writeDict(dict)
    }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }
        let tmp = fileURL.deletingLastPathComponent().appendingPathComponent("mode_state.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                _ = try? fileManager.replaceItemAt(fileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: fileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
        }
    }

    private func migrateLegacyIfNeeded() {
        guard readDict()[Self.key] == nil else { return }
        let legacy = AppConfig.getDBFolderURL()
            .appendingPathComponent("app_settings", isDirectory: true)
            .appendingPathComponent(sanitizeLegacyKey(Self.legacyKey) + ".plist")
        guard fileManager.fileExists(atPath: legacy.path),
              let data = try? Data(contentsOf: legacy),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let raw = plist as? String,
              AppMode(rawValue: raw) != nil else {
            return
        }
        var dict = readDict()
        dict[Self.key] = raw
        writeDict(dict)
    }

    private func sanitizeLegacyKey(_ key: String) -> String {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        return safe.isEmpty ? "key" : safe
    }
}
