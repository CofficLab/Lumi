import LumiUI
import SwiftUI

// MARK: - Menu Row

/// 面包屑下拉菜单中的单行视图
public struct MenuRow: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let sibling: BreadcrumbSibling
    public let isCurrent: Bool
    public let onSelectFile: (URL) -> Void

    public var body: some View {
        Button {
            onSelectFile(sibling.url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.appMicro)
                    .foregroundColor(iconColor)
                    .frame(width: 14)

                Text(sibling.name)
                    .font(.appCaption)

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.appMicroEmphasized)
                        .foregroundColor(theme.primary)
                }
            }
        }
    }

    // MARK: - Icon

    private var iconName: String {
        if sibling.isDirectory {
            return "folder.fill"
        }
        let ext = sibling.url.pathExtension.lowercased()
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
        default: return "doc"
        }
    }

    private var iconColor: Color {
        if sibling.isDirectory {
            return Color.blue
        }
        let ext = sibling.url.pathExtension.lowercased()
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
