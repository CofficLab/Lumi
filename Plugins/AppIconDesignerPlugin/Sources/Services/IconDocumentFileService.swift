import Foundation

public struct IconDocumentFileService {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(document: IconDocument, to url: URL) throws {
        let data = try encoder.encode(IconDocumentSanitizer.sanitized(document))
        try data.write(to: url, options: .atomic)
    }

    public func load(from url: URL) throws -> IconDocument {
        let data = try Data(contentsOf: url)
        return try IconDocumentSanitizer.sanitized(decoder.decode(IconDocument.self, from: data))
    }
}
