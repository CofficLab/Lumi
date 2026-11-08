import Foundation

/// README 预览
public enum ReadmePreviewSection {
    private static let maxChars = 500
    private static let maxBytes = maxChars * 4
    private static let candidates = ["README.md", "README.markdown", "README"]

    /// 读取并预览 README 文件
    public static func render(at root: URL) -> String {
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
            // `text` 本身已被 2,000 字节上限截断：`preview.count < text.count` 只能
            // 发现字符数超限，发现不了"读取块恰好结束在完整字符边界、文件后面还有
            // 内容"的情况。必须再看文件是否还有未读字节。
            let hasMoreBytes = (try? handle.read(upToCount: 1))?.isEmpty == false
            let preview = String(text.prefix(maxChars))
            if preview.count < text.count || hasMoreBytes { return "\(preview)\n..." }
            return preview
        }
        return ""
    }
}
