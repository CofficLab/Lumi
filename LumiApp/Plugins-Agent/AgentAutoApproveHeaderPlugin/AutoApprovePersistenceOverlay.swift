import SwiftUI

struct AutoApprovePersistenceOverlay<Content: View>: View {
    @EnvironmentObject private var projectVM: ProjectVM

    let content: Content
    private let store = AgentAutoApprovePersistenceStore()

    @State private var restored = false

    var body: some View {
        content
            .onAppear {
                handleOnAppear()
            }
            .onChange(of: projectVM.autoApproveRisk) { _, newValue in
                handleAutoApproveRiskChange(newValue)
            }
    }
}

// MARK: - View

// MARK: - Action

// MARK: - Setter

extension AutoApprovePersistenceOverlay {
    @MainActor
    private func setRestored(_ value: Bool) {
        restored = value
    }
}

// MARK: - Event Handler

extension AutoApprovePersistenceOverlay {
    private func handleOnAppear() {
        restoreIfNeeded()
    }

    private func handleAutoApproveRiskChange(_ newValue: Bool) {
        store.saveEnabled(newValue)
    }

    private func restoreIfNeeded() {
        guard !restored else { return }
        setRestored(true)
        guard let enabled = store.loadEnabled() else { return }
        projectVM.setAutoApproveRisk(enabled)
    }
}

// MARK: - Preview

#Preview("Auto Approve Persistence Overlay") {
    AutoApprovePersistenceOverlay {
        Text("Content")
    }
    .inRootView()
}

// MARK: - Persistence Store

private final class AgentAutoApprovePersistenceStore {
    private let fileManager = FileManager.default
    private let fileURL: URL

    private static let key = "autoApproveRisk"
    private static let legacyKey = "Agent_AutoApproveRisk"

    init() {
        let settingsDir = AppConfig.getDBFolderURL()
            .appendingPathComponent("AgentAutoApproveHeader", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.fileURL = settingsDir.appendingPathComponent("auto_approve_state.plist")
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        migrateLegacyIfNeeded()
    }

    func loadEnabled() -> Bool? {
        guard let value = readDict()[Self.key] as? Bool else { return nil }
        return value
    }

    func saveEnabled(_ enabled: Bool) {
        var dict = readDict()
        dict[Self.key] = enabled
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
        let tmp = fileURL.deletingLastPathComponent().appendingPathComponent("auto_approve_state.tmp")
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
              let value = plist as? Bool else {
            return
        }
        var dict = readDict()
        dict[Self.key] = value
        writeDict(dict)
    }

    private func sanitizeLegacyKey(_ key: String) -> String {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        return safe.isEmpty ? "key" : safe
    }
}