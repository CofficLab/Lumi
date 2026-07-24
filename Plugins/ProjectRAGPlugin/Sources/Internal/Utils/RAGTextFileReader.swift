import Foundation

public enum RAGTextFileReader {
    public static func read(path: String) throws -> String {
        var encoding = String.Encoding.utf8
        return try String(contentsOfFile: path, usedEncoding: &encoding)
    }
}
