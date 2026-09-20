import Foundation

enum EditorTextFileReader {
    static func read(_ url: URL) throws -> String {
        var detectedEncoding = String.Encoding.utf8
        return try String(contentsOf: url, usedEncoding: &detectedEncoding)
    }
}
