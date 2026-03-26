import CryptoKit
import Foundation

enum RAGEmbedding {
    static func embed(_ text: String, dimension: Int) -> [Float] {
        var vector = [Float](repeating: 0, count: dimension)
        let normalized = text.lowercased()
        let tokens = tokenize(normalized)

        if tokens.isEmpty { return vector }

        for token in tokens {
            let digest = SHA256.hash(data: Data(token.utf8))
            let bytes = Array(digest)
            if bytes.count < 2 { continue }

            let index = Int(bytes[0]) % dimension
            let sign: Float = (bytes[1] & 1) == 0 ? 1 : -1
            vector[index] += sign
        }

        return normalize(vector)
    }

    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var buffer = ""

        for scalar in text.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if !buffer.isEmpty {
                tokens.append(buffer)
                buffer.removeAll(keepingCapacity: true)
            }

            if scalar.isCJK {
                tokens.append(String(scalar))
            }
        }

        if !buffer.isEmpty {
            tokens.append(buffer)
        }
        return tokens
    }

    private static func normalize(_ vector: [Float]) -> [Float] {
        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        guard norm > 0 else { return vector }
        return vector.map { $0 / norm }
    }
}

extension UnicodeScalar {
    var isCJK: Bool {
        switch value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF:
            return true
        default:
            return false
        }
    }
}
