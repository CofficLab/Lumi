import Foundation

/// 关键文件检测
public enum KeyFilesSection {
    /// 检测关键文件是否存在
    public static func render(at root: URL) -> String {
        let fm = FileManager.default
        func exists(_ name: String) -> Bool {
            fm.fileExists(atPath: root.appendingPathComponent(name).path)
        }
        var lines: [String] = []
        if let readme = ReadmePreviewSection.candidates.first(where: { exists($0) }) {
            lines.append("- README: \(readme)")
        } else {
            lines.append("- README: None")
        }
        lines.append(exists("LICENSE") ? "- LICENSE: LICENSE" : "- LICENSE: None")
        lines.append(exists(".gitignore") ? "- .gitignore: Yes" : "- .gitignore: No")
        return lines.joined(separator: "\n")
    }
}
