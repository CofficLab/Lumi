import CryptoKit
import Foundation

public extension LumiPreviewFacade {
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
                fileManager: fileManager,
                from: self.storageURL,
                decoder: self.decoder
            )
        }

        public func makeCacheKey(
            for fileURL: URL,
            buildStrategy: LumiPreviewFacade.BuildStrategy
        ) -> CacheKey {
            CacheKey(
                fingerprint: Self.sha256(
                    [
                        "compile-command-cache-v2",
                        fileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                        Self.fileFingerprint(fileURL),
                        String(describing: buildStrategy),
                        Self.buildStrategyFingerprint(buildStrategy),
                        Self.developerEnvironmentFingerprint()
                    ].joined(separator: "\u{1f}")
                )
            )
        }

        public func command(for key: CacheKey) -> String? {
            commandsByFingerprint[key.fingerprint]?.command
        }

        public func removeCommand(for key: CacheKey) {
            guard commandsByFingerprint.removeValue(forKey: key.fingerprint) != nil else {
                return
            }
            persist()
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

        public func store(commands: [URL: String], for buildStrategy: LumiPreviewFacade.BuildStrategy) {
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

        static func corruptStorageURL(for storageURL: URL) -> URL {
            storageURL
                .deletingPathExtension()
                .appendingPathExtension("corrupt.json")
        }

        private static func loadCommands(
            fileManager: FileManager,
            from storageURL: URL,
            decoder: JSONDecoder
        ) -> [String: StoredCommand] {
            guard fileManager.fileExists(atPath: storageURL.path) else {
                return [:]
            }

            do {
                let data = try Data(contentsOf: storageURL)
                let decoded = try decoder.decode([StoredCommand].self, from: data)
                var commands: [String: StoredCommand] = [:]
                for command in decoded {
                    commands[command.fingerprint] = command
                }
                return commands
            } catch {
                quarantineCorruptStorage(fileManager: fileManager, storageURL: storageURL)
                return [:]
            }
        }

        private static func quarantineCorruptStorage(fileManager: FileManager, storageURL: URL) {
            guard fileManager.fileExists(atPath: storageURL.path) else { return }

            let corruptURL = corruptStorageURL(for: storageURL)
            do {
                if fileManager.fileExists(atPath: corruptURL.path) {
                    try fileManager.removeItem(at: corruptURL)
                }
                try fileManager.moveItem(at: storageURL, to: corruptURL)
            } catch {
                // Cache recovery is best-effort; a failed quarantine should not block previews.
            }
        }

        private static func defaultCacheDirectory() -> URL {
            PreviewStorage.paths.compileCommandCacheDirectory
        }

        private static func buildStrategyFingerprint(_ buildStrategy: LumiPreviewFacade.BuildStrategy) -> String {
            switch buildStrategy {
            case .spm(let packageDirectory, _):
                return fileFingerprint(packageDirectory.appendingPathComponent("Package.swift"))
            case .xcode(let projectURL, _, _):
                return xcodeContainerFingerprint(projectURL)
            case .incremental(let fileURL, let compileCommand):
                return [
                    fileFingerprint(fileURL),
                    sha256(compileCommand)
                ].joined(separator: "|")
            }
        }

        private static func xcodeContainerFingerprint(_ projectURL: URL) -> String {
            let fingerprintURL: URL
            if projectURL.pathExtension == "xcworkspace" {
                fingerprintURL = projectURL.appendingPathComponent("contents.xcworkspacedata")
            } else {
                fingerprintURL = projectURL.appendingPathComponent("project.pbxproj")
            }
            return fileFingerprint(fingerprintURL)
        }

        private static func fileFingerprint(_ url: URL) -> String {
            let standardizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
            guard let values = try? standardizedURL.resourceValues(
                forKeys: [.contentModificationDateKey, .fileSizeKey]
            ) else {
                return "\(standardizedURL.path)|missing"
            }

            let modifiedAt = values.contentModificationDate?.timeIntervalSince1970 ?? 0
            let fileSize = values.fileSize ?? 0
            return "\(standardizedURL.path)|\(fileSize)|\(modifiedAt)"
        }

        private static func developerEnvironmentFingerprint() -> String {
            let environment = ProcessInfo.processInfo.environment
            return [
                "DEVELOPER_DIR=\(environment["DEVELOPER_DIR"] ?? "")",
                "SDKROOT=\(environment["SDKROOT"] ?? "")",
                "TOOLCHAINS=\(environment["TOOLCHAINS"] ?? "")"
            ].joined(separator: "|")
        }

        private static func sha256(_ text: String) -> String {
            SHA256.hash(data: Data(text.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
        }
    }
}
