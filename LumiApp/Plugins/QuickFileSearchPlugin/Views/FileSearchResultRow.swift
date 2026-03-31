import SwiftUI
import AppKit

/// 文件搜索结果行视图
struct FileSearchResultRow: View {
    let result: FileResult
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            // 文件图标
            icon

            // 文件信息
            VStack(alignment: .leading, spacing: 2) {
                // 文件名
                Text(result.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 相对路径
                Text(result.relativePath)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 匹配分数指示（可选，调试用）
            if result.score > 0 {
                Text("+\(result.score)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
    }

    private var icon: some View {
        Group {
            if result.isDirectory {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: iconName(for: result.name))
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 14))
        .frame(width: 20, alignment: .leading)
    }

    private var rowBackground: some View {
        Group {
            if isSelected {
                Color.accentColor.opacity(0.15)
            } else {
                Color.clear
            }
        }
    }

    /// 根据文件扩展名返回对应图标
    private func iconName(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()

        switch ext {
        // 开发语言
        case "swift": return "swift"
        case "js", "mjs", "cjs": return "doc.text"
        case "ts", "tsx": return "doc.text"
        case "py": return "doc.text"
        case "java": return "doc.text"
        case "kt": return "doc.text"
        case "go": return "doc.text"
        case "rs": return "doc.text"
        case "cpp", "cc", "cxx": return "doc.text"
        case "c", "h": return "doc.text"
        case "m", "mm", "h": return "doc.text"

        // 标记语言
        case "md", "markdown": return "doc.text"
        case "txt": return "doc.text"
        case "rtf": return "doc.richtext"
        case "json": return "doc.text"
        case "xml", "yaml", "yml", "toml", "ini", "plist": return "doc.text"

        // 样式文件
        case "css", "scss", "sass", "less": return "doc.text"
        case "html", "htm": return "doc.text"

        // 图片
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"

        // 文档
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.richtext"
        case "xls", "xlsx": return "doc.richtext"
        case "ppt", "pptx": return "doc.richtext"

        // 音视频
        case "mp3", "wav", "m4a": return "music.note"
        case "mp4", "mov", "avi", "mkv": return "film"

        // 压缩文件
        case "zip", "tar", "gz", "rar", "7z": return "archivebox"

        // 配置文件
        case "env", "config", "conf": return "gearshape"

        default:
            return "doc"
        }
    }
}

// MARK: - Preview

#Preview("File Search Result Row") {
    VStack(spacing: 0) {
        FileSearchResultRow(
            result: FileResult(
                name: "QuickFileSearchPlugin.swift",
                path: "/Test/QuickFileSearchPlugin.swift",
                relativePath: "QuickFileSearchPlugin.swift",
                isDirectory: false,
                score: 100
            ),
            isSelected: false
        )

        FileSearchResultRow(
            result: FileResult(
                name: "Models",
                path: "/Test/Models",
                relativePath: "Models",
                isDirectory: true,
                score: 80
            ),
            isSelected: true
        )

        FileSearchResultRow(
            result: FileResult(
                name: "README.md",
                path: "/Test/README.md",
                relativePath: "README.md",
                isDirectory: false,
                score: 60
            ),
            isSelected: false
        )
    }
    .frame(width: 500)
    .background(Color(nsColor: .controlBackgroundColor))
}
