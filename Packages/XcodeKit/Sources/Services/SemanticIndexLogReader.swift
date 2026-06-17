import Foundation

/// Reads semantic index build logs without loading entire files into memory.
public enum SemanticIndexLogReader {
    public static let defaultMaxTailBytes = 65_536
    public static let defaultMaxLines = 40

    public static func tailExcerpt(
        at logURL: URL,
        maxTailBytes: Int = defaultMaxTailBytes,
        maxLines: Int = defaultMaxLines
    ) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: logURL) else { return nil }
        defer { try? handle.close() }

        let fileSize: UInt64
        do {
            fileSize = try handle.seekToEnd()
        } catch {
            return nil
        }
        guard fileSize > 0 else { return nil }

        let readOffset = fileSize > UInt64(maxTailBytes) ? fileSize - UInt64(maxTailBytes) : 0
        do {
            try handle.seek(toOffset: readOffset)
        } catch {
            return nil
        }

        let data = handle.readDataToEndOfFile()
        guard !data.isEmpty,
              var content = String(data: data, encoding: .utf8) else {
            return nil
        }

        if readOffset > 0, let firstNewline = content.firstIndex(of: "\n") {
            content = String(content[content.index(after: firstNewline)...])
        }
        guard !content.isEmpty else { return nil }

        let lines = content
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .suffix(maxLines)
        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}
