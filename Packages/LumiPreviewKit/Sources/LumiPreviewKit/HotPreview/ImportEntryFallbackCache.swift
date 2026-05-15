import CryptoKit
import Foundation

public extension LumiPreviewPackage {
    actor ImportEntryFallbackCache {
        public struct CacheKey: Sendable, Hashable {
            public let fingerprint: String

            public init(fingerprint: String) {
                self.fingerprint = fingerprint
            }
        }

        private var fingerprints: Set<String> = []

        public init() {}

        public func makeCacheKey(
            discovery: LumiPreviewPackage.PreviewDiscovery,
            configuration: LumiPreviewPackage.PreviewRenderConfiguration,
            buildStrategy: LumiPreviewPackage.BuildStrategy,
            moduleArtifactFingerprint: String? = nil
        ) -> CacheKey {
            CacheKey(
                fingerprint: Self.sha256(
                    [
                        "import-entry-fallback-v1",
                        discovery.id,
                        discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                        "\(discovery.lineNumber)",
                        "\(discovery.endLineNumber)",
                        discovery.title,
                        discovery.primaryTypeName ?? "",
                        discovery.bodySource ?? "",
                        Self.configurationFingerprint(configuration),
                        String(describing: buildStrategy),
                        moduleArtifactFingerprint ?? ""
                    ].joined(separator: "\u{1f}")
                )
            )
        }

        public func contains(_ key: CacheKey) -> Bool {
            fingerprints.contains(key.fingerprint)
        }

        public func recordFailure(for key: CacheKey) {
            fingerprints.insert(key.fingerprint)
        }

        public func remove(_ key: CacheKey) {
            fingerprints.remove(key.fingerprint)
        }
    }
}

private extension LumiPreviewPackage.ImportEntryFallbackCache {
    static func configurationFingerprint(
        _ configuration: LumiPreviewPackage.PreviewRenderConfiguration
    ) -> String {
        guard let data = try? JSONEncoder().encode(configuration),
              let text = String(data: data, encoding: .utf8) else {
            return String(describing: configuration)
        }
        return text
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
