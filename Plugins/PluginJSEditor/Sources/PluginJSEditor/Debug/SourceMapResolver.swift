import Foundation

public enum SourceMapResolver {
    public static func sourceMapURL(for generatedFileURL: URL) -> URL? {
        let sibling = generatedFileURL.deletingPathExtension()
            .appendingPathExtension("\(generatedFileURL.pathExtension).map")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }

        guard let content = try? String(contentsOf: generatedFileURL, encoding: .utf8),
              let markerRange = content.range(of: "sourceMappingURL=", options: .backwards) else {
            return nil
        }

        let tail = sourceMapTail(in: content[markerRange.upperBound...])
        guard let tail else { return nil }
        return resolveSourceMapTail(tail, relativeTo: generatedFileURL)
    }

    static func sourceMapTail(in content: Substring) -> String? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return nil }

        if first == "\"" || first == "'" {
            let bodyStart = trimmed.index(after: trimmed.startIndex)
            if let closingQuote = trimmed[bodyStart...].firstIndex(of: first) {
                return String(trimmed[bodyStart..<closingQuote])
            }
        }

        return trimmed
            .split(whereSeparator: { $0.isNewline || $0 == " " || $0 == "\t" })
            .first
            .map(String.init)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }

    static func resolveSourceMapTail(_ tail: String, relativeTo generatedFileURL: URL) -> URL? {
        if tail.hasPrefix("/") {
            return URL(fileURLWithPath: tail)
        }

        if tail.lowercased().hasPrefix("file://") {
            let rawPath = String(tail.dropFirst("file://".count))
            let path = rawPath
                .replacingOccurrences(of: "^localhost", with: "", options: .regularExpression)
                .removingPercentEncoding ?? rawPath
            return URL(fileURLWithPath: path)
        }

        if let url = URL(string: tail), url.scheme != nil {
            return url
        }

        return generatedFileURL.deletingLastPathComponent().appendingPathComponent(tail)
    }
}
