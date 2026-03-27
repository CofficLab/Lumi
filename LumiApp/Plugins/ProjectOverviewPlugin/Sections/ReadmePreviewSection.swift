import Foundation

enum ReadmePreviewSection {
    private static let maxChars = 500
    private static let maxBytes = maxChars * 4
    private static let candidates = ["README.md", "README.markdown", "README"]

    static func render(at root: URL) -> String {
        let fm = FileManager.default
        for name in candidates {
            let url = root.appendingPathComponent(name)
            guard fm.fileExists(atPath: url.path),
                  let handle = try? FileHandle(forReadingFrom: url)
            else { continue }
            defer { try? handle.close() }
            guard let data = try? handle.read(upToCount: maxBytes),
                  let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { continue }
            let preview = String(text.prefix(maxChars))
            if preview.count < text.count { return "\(preview)\n..." }
            return preview
        }
        return ""
    }
}
