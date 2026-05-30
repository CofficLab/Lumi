import Foundation

public enum SourceMapResolver {
    public static func sourceMapURL(for generatedFileURL: URL) -> URL? {
        let sibling = generatedFileURL.deletingPathExtension()
            .appendingPathExtension("\(generatedFileURL.pathExtension).map")
        if FileManager.default.fileExists(atPath: sibling.path) {
            return sibling
        }

        guard let content = try? String(contentsOf: generatedFileURL, encoding: .utf8),
              let markerRange = content.range(of: "sourceMappingURL=") else {
            return nil
        }

        let tail = content[markerRange.upperBound...]
            .split(whereSeparator: { $0.isNewline || $0 == " " })
            .first
            .map(String.init)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard let tail else { return nil }
        return URL(string: tail) ?? generatedFileURL.deletingLastPathComponent().appendingPathComponent(tail)
    }
}
