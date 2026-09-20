import CryptoKit
import Foundation

public enum DocumentHighlightDigest {
    public static func compute(for content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
