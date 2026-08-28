import Foundation

@MainActor
enum EditorFileIcon {
    static func systemName(for node: EditorFileTreeNode) -> String {
        if node.canExpand {
            return node.isExpanded ? "folder.fill" : "folder"
        }
        switch node.url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "curlybraces"
        case "json", "yaml", "yml": return "text.document"
        case "md", "markdown": return "text.document.fill"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        default: return node.isSymbolicLink ? "link" : "doc"
        }
    }
}
