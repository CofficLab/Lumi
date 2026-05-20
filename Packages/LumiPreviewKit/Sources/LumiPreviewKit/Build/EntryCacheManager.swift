import CryptoKit
import Foundation

public extension LumiPreviewFacade {
    actor EntryCacheManager {
        public struct CacheKey: Sendable, Hashable {
            public let fingerprint: String

            public init(fingerprint: String) {
                self.fingerprint = fingerprint
            }
        }

        private struct EntryMetadata: Codable, Sendable {
            let fingerprint: String
            let dylibPath: String
            var lastAccessedAt: Date
            var createdAt: Date
        }

        private let fileManager: FileManager
        private let cacheRootDirectory: URL
        private let metadataURL: URL
        private let maximumEntryCount: Int
        private var entries: [String: EntryMetadata]
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        public init(
            fileManager: FileManager = .default,
            cacheRootDirectory: URL? = nil,
            maximumEntryCount: Int = 32
        ) {
            self.fileManager = fileManager
            self.cacheRootDirectory = cacheRootDirectory ?? Self.defaultCacheRootDirectory()
            self.metadataURL = self.cacheRootDirectory.appendingPathComponent("entry-cache.json")
            self.maximumEntryCount = max(maximumEntryCount, 1)
            self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            self.encoder.dateEncodingStrategy = .iso8601
            self.decoder.dateDecodingStrategy = .iso8601
            self.entries = Self.loadMetadata(
                fileManager: fileManager,
                metadataURL: self.metadataURL,
                decoder: self.decoder
            )
            self.entries = Self.trimmedEntries(self.entries, maximumEntryCount: self.maximumEntryCount)
        }

        public func makeCacheKey(
            discovery: LumiPreviewFacade.PreviewDiscovery,
            configuration: LumiPreviewFacade.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewFacade.BuildStrategy?,
            entryVariant: String = "default"
        ) -> CacheKey {
            CacheKey(
                fingerprint: Self.sha256(
                    [
                        "entry-cache-v2",
                        discovery.id,
                        discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                        "\(discovery.lineNumber)",
                        "\(discovery.endLineNumber)",
                        discovery.title,
                        discovery.primaryTypeName ?? "",
                        discovery.bodySource ?? "",
                        Self.configurationFingerprint(configuration),
                        String(describing: buildStrategy),
                        entryVariant
                    ].joined(separator: "\u{1f}")
                )
            )
        }

        public func cachedEntryURL(for key: CacheKey) -> URL? {
            guard var entry = entries[key.fingerprint] else {
                return nil
            }

            let url = URL(fileURLWithPath: entry.dylibPath)
            guard fileManager.fileExists(atPath: url.path) else {
                entries.removeValue(forKey: key.fingerprint)
                persistMetadata()
                return nil
            }

            entry.lastAccessedAt = Date()
            entries[key.fingerprint] = entry
            persistMetadata()
            return url
        }

        public func storeEntryURL(_ url: URL, for key: CacheKey) {
            entries[key.fingerprint] = EntryMetadata(
                fingerprint: key.fingerprint,
                dylibPath: url.path,
                lastAccessedAt: Date(),
                createdAt: Date()
            )
            trimIfNeeded()
            persistMetadata()
        }

        public func removeAll() {
            entries.removeAll()
            try? fileManager.removeItem(at: cacheRootDirectory)
        }

        public func cachedEntryCount() -> Int {
            entries.count
        }

        private func trimIfNeeded() {
            entries = Self.trimmedEntries(entries, maximumEntryCount: maximumEntryCount)
        }

        private static func trimmedEntries(
            _ entries: [String: EntryMetadata],
            maximumEntryCount: Int
        ) -> [String: EntryMetadata] {
            guard entries.count > maximumEntryCount else { return entries }

            let sortedEntries = entries.values.sorted { lhs, rhs in
                if lhs.lastAccessedAt == rhs.lastAccessedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.lastAccessedAt < rhs.lastAccessedAt
            }

            var trimmed = entries
            let overflow = entries.count - maximumEntryCount
            for entry in sortedEntries.prefix(overflow) {
                trimmed.removeValue(forKey: entry.fingerprint)
            }
            return trimmed
        }

        private static func loadMetadata(
            fileManager: FileManager,
            metadataURL: URL,
            decoder: JSONDecoder
        ) -> [String: EntryMetadata] {
            guard let data = try? Data(contentsOf: metadataURL),
                  let decoded = try? decoder.decode([EntryMetadata].self, from: data) else {
                return [:]
            }

            var loaded: [String: EntryMetadata] = [:]
            for entry in decoded {
                let url = URL(fileURLWithPath: entry.dylibPath)
                if fileManager.fileExists(atPath: url.path) {
                    loaded[entry.fingerprint] = entry
                }
            }
            return loaded
        }

        private func persistMetadata() {
            do {
                try fileManager.createDirectory(at: cacheRootDirectory, withIntermediateDirectories: true)
                let data = try encoder.encode(entries.values.sorted { $0.lastAccessedAt > $1.lastAccessedAt })
                try data.write(to: metadataURL, options: .atomic)
            } catch {
                // Cache metadata persistence is best-effort.
            }
        }

        private static func configurationFingerprint(_ configuration: LumiPreviewFacade.PreviewRenderConfiguration) -> String {
            guard let data = try? JSONEncoder().encode(configuration),
                  let text = String(data: data, encoding: .utf8) else {
                return String(describing: configuration)
            }
            return text
        }

        private static func sha256(_ text: String) -> String {
            SHA256.hash(data: Data(text.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
        }

        private static func defaultCacheRootDirectory() -> URL {
            PreviewStorage.paths.entryCacheDirectory
        }
    }
}
