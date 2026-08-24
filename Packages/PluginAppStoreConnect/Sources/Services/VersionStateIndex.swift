import Foundation

/// Maps App Store version IDs to `appStoreState` for retention policy resolution.
final class VersionStateIndex: @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "VersionStateIndex.queue", qos: .utility)
    private var states: [String: String] = [:]

    init(indexesDirectory: URL, fileManager: FileManager = .default) {
        self.fileURL = indexesDirectory.appendingPathComponent(
            ConnectAPICacheConfiguration.versionStatesFileName,
            isDirectory: false
        )
        self.fileManager = fileManager
        try? fileManager.createDirectory(at: indexesDirectory, withIntermediateDirectories: true)
        queue.sync {
            states = loadLocked()
        }
    }

    func state(forVersionID versionID: String) -> String? {
        queue.sync { states[versionID] }
    }

    func retention(forVersionID versionID: String) -> ConnectCacheRetention {
        guard let state = state(forVersionID: versionID)?.uppercased() else {
            return .standard
        }
        if state == "READY_FOR_SALE" {
            return .immutable
        }
        if state == "PENDING_DEVELOPER_RELEASE" {
            return .stable
        }
        return .standard
    }

    func update(fromVersionsListResponse data: Data, appID: String) {
        queue.sync {
            guard let parsed = Self.parseVersionsList(data) else { return }
            for (versionID, state) in parsed {
                states[versionID] = state
            }
            _ = appID
            saveLocked()
        }
    }

    func prune(keepingVersionIDs: Set<String>) {
        queue.sync {
            states = states.filter { keepingVersionIDs.contains($0.key) }
            saveLocked()
        }
    }

    func clear() {
        queue.sync {
            states.removeAll()
            saveLocked()
        }
    }

    private func loadLocked() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveLocked() {
        try? fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(states) else { return }
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        do {
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: fileURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
        }
    }

    private static func parseVersionsList(_ data: Data) -> [String: String]? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]] else {
            return nil
        }

        var result: [String: String] = [:]
        for item in items {
            guard let id = item["id"] as? String,
                  let attributes = item["attributes"] as? [String: Any],
                  let state = attributes["appStoreState"] as? String else {
                continue
            }
            result[id] = state
        }
        return result.isEmpty ? nil : result
    }
}
