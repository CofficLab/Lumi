import CryptoKit
import Foundation

final class ConnectAPICacheDiskStore: @unchecked Sendable {
    let rootDirectory: URL
    let objectsDirectory: URL
    private let manifestURL: URL
    private let fileManager: FileManager
    private let diskByteLimit: Int64
    private let diskTargetByteCount: Int64
    private let queue = DispatchQueue(label: "ConnectAPICacheDiskStore.queue", qos: .utility)

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        diskByteLimit: Int64 = ConnectAPICacheConfiguration.diskByteLimit,
        diskTargetByteCount: Int64 = ConnectAPICacheConfiguration.diskTargetByteCount
    ) {
        self.rootDirectory = rootDirectory
        self.objectsDirectory = rootDirectory.appendingPathComponent(
            ConnectAPICacheConfiguration.objectsDirectoryName,
            isDirectory: true
        )
        self.manifestURL = rootDirectory.appendingPathComponent(ConnectAPICacheConfiguration.manifestFileName)
        self.fileManager = fileManager
        self.diskByteLimit = diskByteLimit
        self.diskTargetByteCount = diskTargetByteCount
        try? fileManager.createDirectory(at: objectsDirectory, withIntermediateDirectories: true)
        reconcile()
    }

    static func objectName(for logicalKey: String) -> String {
        let digest = SHA256.hash(data: Data(logicalKey.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func objectURL(for objectName: String) -> URL {
        objectsDirectory.appendingPathComponent("\(objectName).json", isDirectory: false)
    }

    func read(
        logicalKey: String,
        now: Date = Date()
    ) -> (data: Data, entry: ConnectAPICacheEntry)? {
        queue.sync {
            var manifest = loadManifest()
            guard let index = manifest.entries.firstIndex(where: { $0.key == logicalKey }) else {
                return nil
            }
            var entry = manifest.entries[index]
            if entry.retention.isExpired(fetchedAt: entry.fetchedAt, now: now) {
                removeEntryLocked(key: logicalKey, manifest: &manifest)
                saveManifest(manifest)
                return nil
            }

            let url = objectURL(for: entry.objectName)
            guard let data = try? Data(contentsOf: url),
                  !data.isEmpty,
                  data.count == entry.byteCount else {
                removeEntryLocked(key: logicalKey, manifest: &manifest)
                saveManifest(manifest)
                return nil
            }

            entry.lastAccess = now
            manifest.entries[index] = entry
            saveManifest(manifest)
            return (data, entry)
        }
    }

    @discardableResult
    func store(
        logicalKey: String,
        method: String,
        path: String,
        retention: ConnectCacheRetention,
        tags: [ConnectCacheTag],
        data: Data,
        now: Date = Date()
    ) -> Bool {
        queue.sync {
            let objectName = Self.objectName(for: logicalKey)
            let objectURL = objectURL(for: objectName)
            let temporaryURL = objectsDirectory.appendingPathComponent("\(objectName).tmp", isDirectory: false)

            do {
                try data.write(to: temporaryURL, options: .atomic)
                if fileManager.fileExists(atPath: objectURL.path) {
                    try fileManager.removeItem(at: objectURL)
                }
                try fileManager.moveItem(at: temporaryURL, to: objectURL)
            } catch {
                try? fileManager.removeItem(at: temporaryURL)
                return false
            }

            var manifest = loadManifest()
            let entry = ConnectAPICacheEntry(
                key: logicalKey,
                objectName: objectName,
                method: method,
                path: path,
                retention: retention,
                byteCount: data.count,
                fetchedAt: now,
                lastAccess: now,
                tags: tags
            )
            if let index = manifest.entries.firstIndex(where: { $0.key == logicalKey }) {
                manifest.entries[index] = entry
            } else {
                manifest.entries.append(entry)
            }
            saveManifest(manifest)
            evictIfNeeded(now: now)
            return true
        }
    }

    func removeEntry(forKey logicalKey: String) {
        queue.sync {
            var manifest = loadManifest()
            removeEntryLocked(key: logicalKey, manifest: &manifest)
            saveManifest(manifest)
        }
    }

    @discardableResult
    func invalidate(tags: Set<ConnectCacheTag>) -> [String] {
        guard !tags.isEmpty else { return [] }
        return queue.sync {
            var manifest = loadManifest()
            let keys = manifest.entries
                .filter { entry in entry.tags.contains(where: { tags.contains($0) }) }
                .map(\.key)
            keys.forEach { removeEntryLocked(key: $0, manifest: &manifest) }
            saveManifest(manifest)
            return keys
        }
    }

    func invalidate(accountKey: String, where predicate: (ConnectAPICacheEntry) -> Bool) {
        queue.sync {
            var manifest = loadManifest()
            let keys = manifest.entries
                .filter { $0.key.hasPrefix("\(accountKey)|") && predicate($0) }
                .map(\.key)
            keys.forEach { removeEntryLocked(key: $0, manifest: &manifest) }
            saveManifest(manifest)
        }
    }

    func pruneVersions(keepingVersionIDs: Set<String>, accountKey: String) {
        queue.sync {
            var manifest = loadManifest()
            let keys = manifest.entries
                .filter { entry in
                    guard entry.key.hasPrefix("\(accountKey)|") else { return false }
                    return entry.tags.contains { tag in
                        if case .version(let id) = tag {
                            return !keepingVersionIDs.contains(id)
                        }
                        return false
                    }
                }
                .map(\.key)
            keys.forEach { removeEntryLocked(key: $0, manifest: &manifest) }
            saveManifest(manifest)
        }
    }

    func clear() {
        queue.sync {
            let manifest = loadManifest()
            manifest.entries.forEach { removeObjectFile(for: $0.objectName) }
            saveManifest(ConnectAPICacheManifest(entries: []))
            removeOrphanObjectFiles(validNames: [])
        }
    }

    func diskUsage() -> ConnectAPICacheDiskUsage {
        queue.sync {
            let manifest = loadManifest()
            let byteCount = manifest.entries.reduce(Int64(0)) { $0 + Int64($1.byteCount) }
            return ConnectAPICacheDiskUsage(fileCount: manifest.entries.count, byteCount: byteCount)
        }
    }

    func reconcile() {
        queue.sync {
            var manifest = loadManifest()
            var changed = false

            manifest.entries = manifest.entries.filter { entry in
                let url = objectURL(for: entry.objectName)
                guard let data = try? Data(contentsOf: url), !data.isEmpty else {
                    removeObjectFile(for: entry.objectName)
                    changed = true
                    return false
                }
                if data.count != entry.byteCount {
                    removeObjectFile(for: entry.objectName)
                    changed = true
                    return false
                }
                return true
            }

            let validNames = Set(manifest.entries.map(\.objectName))
            if removeOrphanObjectFiles(validNames: validNames) {
                changed = true
            }

            let cutoff = Date().addingTimeInterval(-ConnectAPICacheConfiguration.staleAccessInterval)
            let staleKeys = manifest.entries
                .filter { $0.retention != .immutable && $0.lastAccess < cutoff }
                .map(\.key)
            staleKeys.forEach { key in
                removeEntryLocked(key: key, manifest: &manifest)
                changed = true
            }

            if changed {
                saveManifest(manifest)
            }
        }
    }

    private func evictIfNeeded(now: Date = Date()) {
        let manifest = loadManifest()
        var totalBytes = manifest.entries.reduce(Int64(0)) { $0 + Int64($1.byteCount) }
        guard totalBytes > diskByteLimit else { return }

        var workingManifest = manifest
        let sorted = workingManifest.entries.sorted { $0.lastAccess < $1.lastAccess }
        for entry in sorted where totalBytes > diskTargetByteCount {
            removeEntryLocked(key: entry.key, manifest: &workingManifest)
            totalBytes -= Int64(entry.byteCount)
        }
        saveManifest(workingManifest)
    }

    private func removeEntryLocked(key: String, manifest: inout ConnectAPICacheManifest) {
        if let entry = manifest.entries.first(where: { $0.key == key }) {
            removeObjectFile(for: entry.objectName)
        }
        manifest.entries.removeAll { $0.key == key }
    }

    @discardableResult
    private func removeOrphanObjectFiles(validNames: Set<String>) -> Bool {
        guard let files = try? fileManager.contentsOfDirectory(
            at: objectsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        var removed = false
        for fileURL in files where fileURL.pathExtension == "json" {
            let name = fileURL.deletingPathExtension().lastPathComponent
            if !validNames.contains(name) {
                try? fileManager.removeItem(at: fileURL)
                removed = true
            }
        }
        return removed
    }

    private func removeObjectFile(for objectName: String) {
        let url = objectURL(for: objectName)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
        let temporaryURL = objectsDirectory.appendingPathComponent("\(objectName).tmp", isDirectory: false)
        if fileManager.fileExists(atPath: temporaryURL.path) {
            try? fileManager.removeItem(at: temporaryURL)
        }
    }

    private func loadManifest() -> ConnectAPICacheManifest {
        guard let data = try? Data(contentsOf: manifestURL) else {
            return ConnectAPICacheManifest(entries: [])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(ConnectAPICacheManifest.self, from: data) else {
            return ConnectAPICacheManifest(entries: [])
        }
        return manifest
    }

    private func saveManifest(_ manifest: ConnectAPICacheManifest) {
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(manifest) else { return }
        let temporaryURL = rootDirectory.appendingPathComponent("\(ConnectAPICacheConfiguration.manifestFileName).tmp")
        do {
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: manifestURL.path) {
                try fileManager.removeItem(at: manifestURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: manifestURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
        }
    }
}
