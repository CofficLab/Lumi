import Foundation
import SwiftUI

struct LumiFileIconContext {
    let url: URL
    let fileName: String
    let fileExtension: String
    let isDirectory: Bool
    let isExpanded: Bool
    let projectRootPath: String
}

enum LumiFileIcon {
    case systemImage(String)
    case assetImage(name: String, bundle: Bundle?)
}

protocol LumiFileIconThemeContributor: AnyObject {
    var id: String { get }
    var displayName: String { get }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon?
    func defaultFileIcon() -> LumiFileIcon
    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon
}

final class LumiDefaultFileIconThemeContributor: LumiFileIconThemeContributor {
    let id: String
    let displayName: String

    init(id: String = "lumi-default-file-icons", displayName: String = "Lumi File Icons") {
        self.id = id
        self.displayName = displayName
    }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon? {
        if context.isDirectory {
            return folderIcon(for: context.fileName, isExpanded: context.isExpanded)
        }

        if let icon = iconForFileName(context.fileName) {
            return icon
        }

        if let icon = iconForExtension(context.fileExtension) {
            return icon
        }

        return nil
    }

    func defaultFileIcon() -> LumiFileIcon {
        .systemImage("doc")
    }

    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon {
        .systemImage(isExpanded ? "folder.fill" : "folder")
    }

    private func folderIcon(for fileName: String, isExpanded: Bool) -> LumiFileIcon {
        let name = fileName.lowercased()
        switch name {
        case ".github":
            return .systemImage("chevron.left.forwardslash.chevron.right")
        case "sources", "source", "src":
            return .systemImage(isExpanded ? "folder.fill" : "folder")
        case "tests", "test":
            return .systemImage(isExpanded ? "folder.badge.gearshape.fill" : "folder.badge.gearshape")
        default:
            return defaultFolderIcon(isExpanded: isExpanded)
        }
    }

    private func iconForFileName(_ fileName: String) -> LumiFileIcon? {
        switch fileName.lowercased() {
        case ".gitignore", ".gitattributes", ".gitmodules":
            return .systemImage("arrow.triangle.branch")
        case "package.swift":
            return .systemImage("swift")
        case "package.json":
            return .systemImage("shippingbox")
        case "readme", "readme.md", "readme.markdown":
            return .systemImage("book")
        case "license", "license.md", "license.txt":
            return .systemImage("checkmark.seal")
        case "makefile":
            return .systemImage("hammer")
        default:
            return nil
        }
    }

    private func iconForExtension(_ fileExtension: String) -> LumiFileIcon? {
        if let systemImage = Self.systemImageName(forFileExtension: fileExtension) {
            return .systemImage(systemImage)
        }
        return nil
    }

    static func systemImageName(forFileExtension fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "swift":
            return "swift"
        case "m", "mm", "h":
            return "c.circle"
        case "json":
            return "curlybraces"
        case "yaml", "yml":
            return "list.bullet.indent"
        case "xml":
            return "chevron.left.forwardslash.chevron.right"
        case "plist":
            return "gearshape"
        case "xcworkspacedata":
            return "square.stack.3d.up"
        case "xcodeproj":
            return "hammer"
        case "png", "jpg", "jpeg", "gif", "webp", "svg", "icns", "ico":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "md", "markdown":
            return "doc.text"
        case "txt":
            return "doc.plaintext"
        case "rtf":
            return "doc.richtext"
        case "sh", "bash", "zsh":
            return "terminal"
        case "gitignore":
            return "arrow.triangle.branch"
        default:
            return nil
        }
    }
}
