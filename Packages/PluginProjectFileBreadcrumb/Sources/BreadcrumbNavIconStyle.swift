import LumiUI
import SwiftUI

/// 面包屑段图标命名与着色（供视图与单测共用）。
///
/// 图标名统一委托给 LumiUI 的 `LumiDefaultFileIconThemeContributor`，与文件树保持一致；
/// 仅保留按扩展名着色的本地策略（LumiUI 没有统一方案）。
enum BreadcrumbNavIconStyle {
    /// 面包屑段曾用 `Menu` + `.borderlessButton`，macOS 上会吞掉 label 内图标前景色。
    static let usesBorderlessMenuLabel = false

    /// 图标名：文件夹固定 `folder.fill`，文件委托 LumiUI 图标系统，未命中回退 `doc`。
    static func iconName(for item: BreadcrumbItem) -> String {
        if item.isDirectory {
            return "folder.fill"
        }
        let ext = item.url.pathExtension
        if let name = LumiDefaultFileIconThemeContributor.systemImageName(forFileExtension: ext) {
            return name
        }
        return "doc"
    }

    /// 兄弟节点的图标名（MenuRow 使用），与面包屑段保持一致。
    static func iconName(for sibling: BreadcrumbSibling) -> String {
        if sibling.isDirectory {
            return "folder.fill"
        }
        if let name = LumiDefaultFileIconThemeContributor.systemImageName(forFileExtension: sibling.url.pathExtension) {
            return name
        }
        return "doc"
    }

    /// 按扩展名着色。文件夹统一蓝色；文件未命中回退到 `theme.textSecondary`。
    static func iconColor(for item: BreadcrumbItem, theme: any LumiUITheme) -> Color {
        iconColor(isDirectory: item.isDirectory, url: item.url, theme: theme)
    }

    static func iconColor(for sibling: BreadcrumbSibling, theme: any LumiUITheme) -> Color {
        iconColor(isDirectory: sibling.isDirectory, url: sibling.url, theme: theme)
    }

    private static func iconColor(isDirectory: Bool, url: URL, theme: any LumiUITheme) -> Color {
        if isDirectory {
            return Color.blue
        }
        switch url.pathExtension.lowercased() {
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
