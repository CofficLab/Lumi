import Foundation

// MARK: - FileTreeNode Icon Extension

extension FileTreeNode {
    /// 获取节点对应的 SF Symbol 图标名称
    /// - Parameter isExpanded: 是否展开（对于文件夹）
    func icon(isExpanded: Bool = false) -> String {
        if isDirectory {
            return isExpanded ? "folder.fill" : "folder"
        } else {
            return fileIcon
        }
    }

    /// 获取节点图标（使用默认折叠状态）
    var icon: String {
        icon(isExpanded: false)
    }

    /// 根据文件扩展名获取对应的图标
    private var fileIcon: String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "m", "mm": return "m"
        case "h": return "h.square"
        case "xcodeproj", "xcworkspace": return "xmark.shield"
        case "plist": return "doc.plaintext"
        case "json": return "doc.plaintext"
        case "xml": return "doc.plaintext"
        case "md": return "doc.text"
        case "txt": return "doc.text"
        case "rtf": return "doc.richtext"
        case "pdf": return "doc.fill"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo"
        case "zip", "tar", "gz", "rar": return "doc.zipper"
        default: return "doc"
        }
    }
}
