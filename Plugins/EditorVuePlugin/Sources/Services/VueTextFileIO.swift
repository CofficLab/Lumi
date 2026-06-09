import Foundation

enum VueTextFileIO {
    static func read(path: String) throws -> (content: String, encoding: String.Encoding) {
        var encoding = String.Encoding.utf8
        let content = try String(contentsOfFile: path, usedEncoding: &encoding)
        return (content, encoding)
    }

    static func readContent(path: String) throws -> String {
        try read(path: path).content
    }

    static func write(_ content: String, to path: String, encoding: String.Encoding) throws {
        try content.write(toFile: path, atomically: true, encoding: encoding)
    }
}
