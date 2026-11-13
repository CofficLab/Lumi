import Foundation

/// README 预览
public enum ReadmePreviewSection {
    private static let maxChars = 500
    private static let maxBytes = maxChars * 4
    /// README 候选文件（按优先级）。KeyFilesSection 共用此列表，避免两处检测漂移（#479）。
    static let candidates = ["README.md", "README.markdown", "README"]

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
                  let text = decodeUTF8(data)?.trimmingCharacters(in: .whitespacesAndNewlines),
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

    /// 2,000 字节读取块可能正好切在一个多字节字符中间，此时
    /// `String(data:encoding:.utf8)` 整体返回 nil，预览会凭空消失（#369）。
    /// 合法 UTF-8 的连续前缀最多只有 1 个不完整的尾字符（1–3 字节），
    /// 逐字节丢弃尾部即可恢复出完整前缀，而不是放弃整段内容。
    private static func decodeUTF8(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) { return text }
        for drop in 1...3 {
            if let text = String(data: data.dropLast(drop), encoding: .utf8) { return text }
        }
        return nil
    }
}
