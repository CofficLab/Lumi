import CryptoKit
import Foundation

struct ScreenshotCacheEntry: Codable, Equatable {
    let key: String
    let sourceURL: String
    let screenshotID: String?
    let byteCount: Int
    var lastAccess: Date
    let createdAt: Date
}

struct ScreenshotCacheManifest: Codable {
    var entries: [ScreenshotCacheEntry]
}

struct ScreenshotCacheDiskUsage: Equatable {
    let fileCount: Int
    let byteCount: Int64
}

final class ScreenshotCacheDiskStore: @unchecked Sendable {
    let rootDirectory: URL
    let objectsDirectory: URL
    private let manifestURL: URL
    private let fileManager: FileManager
    private let diskByteLimit: Int64
    private let diskTargetByteCount: Int64
    private let queue = DispatchQueue(label: "ScreenshotCacheDiskStore.queue", qos: .utility)

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        diskByteLimit: Int64 = ScreenshotCacheConfiguration.diskByteLimit,
        diskTargetByteCount: Int64 = ScreenshotCacheConfiguration.diskTargetByteCount
    ) {
        self.rootDirectory = rootDirectory
        self.objectsDirectory = rootDirectory.appendingPathComponent(
            ScreenshotCacheConfiguration.objectsDirectoryName,
            isDirectory: true
        )
        self.manifestURL = rootDirectory.appendingPathComponent(ScreenshotCacheConfiguration.manifestFileName)
        self.fileManager = fileManager
        self.diskByteLimit = diskByteLimit
        self.diskTargetByteCount = diskTargetByteCount
        try? fileManager.createDirectory(at: objectsDirectory, withIntermediateDirectories: true)
        reconcile()
    }

    static func cacheKey(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    func objectURL(for key: String) -> URL {
        objectsDirectory.appendingPathComponent("\(key).bin", isDirectory: false)
    }

    func readData(for key: String) -> Data? {
        queue.sync {
            let url = objectURL(for: key)
            guard fileManager.fileExists(atPath: url.path) else { return nil }
            return try? Data(contentsOf: url)
        }
    }

    func touchAccess(for key: String, at date: Date = Date()) {
        queue.sync {
            var manifest = loadManifest()
            guard let index = manifest.entries.firstIndex(where: { $0.key == key }) else { return }
            manifest.entries[index].lastAccess = date
            saveManifest(manifest)
        }
    }

    @discardableResult
    func store(
        key: String,
        sourceURL: URL,
        screenshotID: String?,
        data: Data,
        now: Date = Date()
    ) -> Bool {
        queue.sync {
            let objectURL = objectURL(for: key)
            let temporaryURL = objectsDirectory.appendingPathComponent("\(key).tmp", isDirectory: false)

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
            let entry = ScreenshotCacheEntry(
                key: key,
                sourceURL: sourceURL.absoluteString,
                screenshotID: screenshotID,
                byteCount: data.count,
                lastAccess: now,
                createdAt: manifest.entries.first(where: { $0.key == key })?.createdAt ?? now
            )
            if let index = manifest.entries.firstIndex(where: { $0.key == key }) {
                manifest.entries[index] = entry
            } else {
                manifest.entries.append(entry)
            }
            saveManifest(manifest)
            evictIfNeeded(now: now)
            return true
        }
    }

    func removeEntry(forKey key: String) {
        queue.sync {
            removeEntryLocked(key: key)
        }
    }

    func invalidate(screenshotID: String) {
        queue.sync {
            let keys = loadManifest().entries.filter { $0.screenshotID == screenshotID }.map(\.key)
            keys.forEach { removeEntryLocked(key: $0) }
        }
    }

    func pruneEntries(keepingURLs: Set<URL>) {
        let allowed = Set(keepingURLs.map(\.absoluteString))
        queue.sync {
            let keys = loadManifest().entries
                .filter { !allowed.contains($0.sourceURL) }
                .map(\.key)
            keys.forEach { removeEntryLocked(key: $0) }
        }
    }

    func clear() {
        queue.sync {
            let manifest = loadManifest()
            manifest.entries.forEach { removeObjectFile(for: $0.key) }
            saveManifest(ScreenshotCacheManifest(entries: []))
            removeOrphanObjectFiles(validKeys: [])
        }
    }

    func diskUsage() -> ScreenshotCacheDiskUsage {
        queue.sync {
            let manifest = loadManifest()
            let byteCount = manifest.entries.reduce(Int64(0)) { $0 + Int64($1.byteCount) }
            return ScreenshotCacheDiskUsage(fileCount: manifest.entries.count, byteCount: byteCount)
        }
    }

    func reconcile() {
        queue.sync {
            var manifest = loadManifest()
            var changed = false

            manifest.entries = manifest.entries.filter { entry in
                let url = objectURL(for: entry.key)
                guard let data = try? Data(contentsOf: url), !data.isEmpty else {
                    removeObjectFile(for: entry.key)
                    changed = true
                    return false
                }
                if data.count != entry.byteCount {
                    removeObjectFile(for: entry.key)
                    changed = true
                    return false
                }
                return true
            }

            let validKeys = Set(manifest.entries.map(\.key))
            if removeOrphanObjectFiles(validKeys: validKeys) {
                changed = true
            }

            let cutoff = Date().addingTimeInterval(-ScreenshotCacheConfiguration.staleAccessInterval)
            let staleKeys = manifest.entries.filter { $0.lastAccess < cutoff }.map(\.key)
            staleKeys.forEach { key in
                removeEntryLocked(key: key)
                changed = true
            }

            if changed {
                manifest = loadManifest()
            }
            saveManifest(manifest)
        }
    }

    private func evictIfNeeded(now: Date = Date()) {
        let manifest = loadManifest()
        var totalBytes = manifest.entries.reduce(Int64(0)) { $0 + Int64($1.byteCount) }
        guard totalBytes > diskByteLimit else { return }

        let sorted = manifest.entries.sorted { $0.lastAccess < $1.lastAccess }
        for entry in sorted where totalBytes > diskTargetByteCount {
            removeEntryLocked(key: entry.key)
            totalBytes -= Int64(entry.byteCount)
        }
    }

    private func removeEntryLocked(key: String) {
        removeObjectFile(for: key)
        var manifest = loadManifest()
        manifest.entries.removeAll { $0.key == key }
        saveManifest(manifest)
    }

    @discardableResult
    private func removeOrphanObjectFiles(validKeys: Set<String>) -> Bool {
        guard let files = try? fileManager.contentsOfDirectory(
            at: objectsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }

        var removed = false
        for fileURL in files where fileURL.pathExtension == "bin" {
            let key = fileURL.deletingPathExtension().lastPathComponent
            if !validKeys.contains(key) {
                try? fileManager.removeItem(at: fileURL)
                removed = true
            }
        }
        return removed
    }

    private func removeObjectFile(for key: String) {
        let url = objectURL(for: key)
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
        let temporaryURL = objectsDirectory.appendingPathComponent("\(key).tmp", isDirectory: false)
        if fileManager.fileExists(atPath: temporaryURL.path) {
            try? fileManager.removeItem(at: temporaryURL)
        }
    }

    private func loadManifest() -> ScreenshotCacheManifest {
        guard let data = try? Data(contentsOf: manifestURL) else {
            return ScreenshotCacheManifest(entries: [])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(ScreenshotCacheManifest.self, from: data) else {
            return ScreenshotCacheManifest(entries: [])
        }
        return manifest
    }

    private func saveManifest(_ manifest: ScreenshotCacheManifest) {
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(manifest) else { return }
        let temporaryURL = rootDirectory.appendingPathComponent("\(ScreenshotCacheConfiguration.manifestFileName).tmp")
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
