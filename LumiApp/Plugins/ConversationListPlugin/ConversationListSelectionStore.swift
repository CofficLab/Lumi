import Foundation

final class ConversationListSelectionStore {
    private let fileManager = FileManager.default
    private let fileURL: URL

    private static let storageKey = "selectedConversationId"
    private static let legacyKey: String = {
        #if DEBUG
        return "Conversation_SelectedId_Debug"
        #else
        return "Conversation_SelectedId"
        #endif
    }()

    init() {
        let settingsDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("AgentConversationListPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.fileURL = settingsDir.appendingPathComponent("conversation_selection.plist")
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        migrateLegacyIfNeeded()
    }

    func loadSelectedConversationId() -> UUID? {
        guard let idString = readDict()[Self.storageKey] as? String else { return nil }
        return UUID(uuidString: idString)
    }

    func saveSelectedConversationId(_ id: UUID?) {
        var dict = readDict()
        if let id {
            dict[Self.storageKey] = id.uuidString
        } else {
            dict.removeValue(forKey: Self.storageKey)
        }
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
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else {
            return
        }

        let tmp = fileURL.deletingLastPathComponent().appendingPathComponent("conversation_selection.tmp")
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
        guard readDict()[Self.storageKey] == nil else { return }

        let legacyFile = AppConfig.getDBFolderURL()
            .appendingPathComponent("app_settings", isDirectory: true)
            .appendingPathComponent(sanitizeLegacyKey(Self.legacyKey) + ".plist")

        guard fileManager.fileExists(atPath: legacyFile.path),
              let data = try? Data(contentsOf: legacyFile),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let legacyValue = plist as? String,
              let uuid = UUID(uuidString: legacyValue) else {
            return
        }

        saveSelectedConversationId(uuid)
    }

    private func sanitizeLegacyKey(_ key: String) -> String {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        return safe.isEmpty ? "key" : safe
    }
}
