import Foundation

enum SourceFileTextLoader {
    static func read(_ fileURL: URL) throws -> String {
        var encoding = String.Encoding.utf8
        return try String(contentsOf: fileURL, usedEncoding: &encoding)
    }
}
