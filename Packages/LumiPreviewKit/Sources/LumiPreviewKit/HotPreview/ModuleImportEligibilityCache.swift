import CryptoKit
import Foundation

public extension LumiPreviewPackage {
    actor ModuleImportEligibilityCache {
        public struct CacheKey: Sendable, Hashable {
            public let fingerprint: String

            public init(fingerprint: String) {
                self.fingerprint = fingerprint
            }
        }

        private var values: [String: Bool] = [:]

        public init() {}

        public func makeCacheKey(
            discovery: LumiPreviewPackage.PreviewDiscovery
        ) -> CacheKey {
            CacheKey(
                fingerprint: Self.sha256(
                    [
                        "module-import-eligibility-v1",
                        discovery.id,
                        discovery.sourceFileURL.standardizedFileURL.resolvingSymlinksInPath().path,
                        "\(discovery.lineNumber)",
                        "\(discovery.endLineNumber)",
                        discovery.bodySource ?? "",
                        discovery.sourceText ?? ""
                    ].joined(separator: "\u{1f}")
                )
            )
        }

        public func value(for key: CacheKey) -> Bool? {
            values[key.fingerprint]
        }

        public func store(_ value: Bool, for key: CacheKey) {
            values[key.fingerprint] = value
        }

        public func removeAll() {
            values.removeAll()
        }
    }
}

private extension LumiPreviewPackage.ModuleImportEligibilityCache {
    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
