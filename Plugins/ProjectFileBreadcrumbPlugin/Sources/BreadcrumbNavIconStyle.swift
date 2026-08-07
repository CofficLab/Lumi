import LumiUI
import SwiftUI

/// 面包屑段图标命名与着色（供视图与单测共用）。
enum BreadcrumbNavIconStyle {
    /// 面包屑段曾用 `Menu` + `.borderlessButton`，macOS 上会吞掉 label 内图标前景色。
    static let usesBorderlessMenuLabel = false

    static func iconName(for item: BreadcrumbItem) -> String {
        if item.isDirectory {
            return "folder.fill"
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "md", "mdx": return "doc.text"
        case "json": return "doc.text"
        case "yaml", "yml", "toml": return "doc.text"
        case "xml", "html": return "doc.text"
        case "css", "scss", "less": return "doc.text"
        case "js", "jsx": return "doc.text"
        case "ts", "tsx": return "doc.text"
        case "py": return "doc.text"
        case "java": return "doc.text"
        case "kt": return "doc.text"
        case "go": return "doc.text"
        case "rs": return "doc.text"
        case "c", "h": return "doc.text"
        case "cpp", "hpp", "cc": return "doc.text"
        case "m", "mm": return "doc.text"
        case "sh", "bash", "zsh": return "terminal"
        case "png", "jpg", "jpeg", "gif", "svg", "ico": return "photo"
        case "pdf": return "doc.richtext"
        case "txt": return "doc.plaintext"
        case "xcodeproj", "xcworkspace": return "hammer"
        default: return "doc"
        }
    }

    static func iconColor(for item: BreadcrumbItem, theme: any LumiUITheme) -> Color {
        if item.isDirectory {
            return Color.blue
        }
        let ext = item.url.pathExtension.lowercased()
        switch ext {
        case "swift": return Color.orange
        case "js", "jsx": return Color.yellow
        case "ts", "tsx": return Color.blue
        case "py": return Color.green
        case "json": return Color.orange
        case "yaml", "yml", "toml": return Color.orange
        case "md", "mdx": return Color.blue
        case "html": return Color.orange
        case "css", "scss": return Color.purple
        case "java": return Color.red
        case "go": return Color.cyan
        case "rs": return Color.orange
        case "sh", "bash", "zsh": return Color.green
        default: return theme.textSecondary
        }
    }
}
