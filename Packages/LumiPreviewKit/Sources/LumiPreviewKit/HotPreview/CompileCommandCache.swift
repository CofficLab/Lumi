import CryptoKit
import Foundation

public extension LumiPreviewPackage {
    actor CompileCommandCache {
        public struct CacheKey: Sendable, Hashable {
            public let fingerprint: String

            public init(fingerprint: String) {
                self.fingerprint = fingerprint
            }
        }

        private struct StoredCommand: Codable, Sendable {
            let fingerprint: String
            let filePath: String
            let command: String
            var updatedAt: Date
        }

        private let fileManager: FileManager
        private let cacheDirectory: URL
        private let storageURL: URL
        private var commandsByFingerprint: [String: StoredCommand]
        private let encoder = JSONEncoder()
        private let decoder = JSONDecoder()

        public init(
            fileManager: FileManager = .default,
            cacheDirectory: URL? = nil
        ) {
            self.fileManager = fileManager
            self.cacheDirectory = cacheDirectory ?? Self.defaultCacheDirectory()
            self.storageURL = self.cacheDirectory.appendingPathComponent("compile-commands.json")
            self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            self.encoder.dateEncodingStrategy = .iso8601
            self.decoder.dateDecodingStrategy = .iso8601
            self.commandsByFingerprint = Self.loadCommands(
                from: self.storageURL,
                decoder: self.decoder
            )
        }

        public func makeCacheKey(
            for fileURL: URL,
            buildStrategy: LumiPreviewPackage.BuildStrategy
        ) -> CacheKey {
            CacheKey(
                fingerprint: Self.sha256(
                    [
                        fileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                        String(describing: buildStrategy)
                    ].joined(separator: "\u{1f}")
                )
            )
        }

        public func command(for key: CacheKey) -> String? {
            commandsByFingerprint[key.fingerprint]?.command
        }

        public func store(command: String, for fileURL: URL, key: CacheKey) {
            commandsByFingerprint[key.fingerprint] = StoredCommand(
                fingerprint: key.fingerprint,
                filePath: fileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                command: command,
                updatedAt: Date()
            )
            persist()
        }

        public func store(commands: [URL: String], for buildStrategy: LumiPreviewPackage.BuildStrategy) {
            for (fileURL, command) in commands {
                let key = makeCacheKey(for: fileURL, buildStrategy: buildStrategy)
                commandsByFingerprint[key.fingerprint] = StoredCommand(
                    fingerprint: key.fingerprint,
                    filePath: fileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                    command: command,
                    updatedAt: Date()
                )
            }
            persist()
        }

        public func removeAll() {
            commandsByFingerprint.removeAll()
            try? fileManager.removeItem(at: cacheDirectory)
        }

        public func entryCount() -> Int {
            commandsByFingerprint.count
        }

        private func persist() {
            do {
                try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
                let payload = commandsByFingerprint.values.sorted { lhs, rhs in
                    if lhs.updatedAt == rhs.updatedAt {
                        return lhs.filePath < rhs.filePath
                    }
                    return lhs.updatedAt > rhs.updatedAt
                }
                let data = try encoder.encode(payload)
                try data.write(to: storageURL, options: .atomic)
            } catch {
                // Persistence is best-effort.
            }
        }

        private static func loadCommands(from storageURL: URL, decoder: JSONDecoder) -> [String: StoredCommand] {
            guard let data = try? Data(contentsOf: storageURL),
                  let decoded = try? decoder.decode([StoredCommand].self, from: data) else {
                return [:]
            }
            return Dictionary(uniqueKeysWithValues: decoded.map { ($0.fingerprint, $0) })
        }

        private static func defaultCacheDirectory() -> URL {
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
                .appendingPathComponent("LumiPreviewKit", isDirectory: true)
                .appendingPathComponent("CompileCommandCache", isDirectory: true)
            ?? FileManager.default.temporaryDirectory
                .appendingPathComponent("LumiPreviewKit-CompileCommandCache", isDirectory: true)
        }

        private static func sha256(_ text: String) -> String {
            SHA256.hash(data: Data(text.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
        }
    }
}
