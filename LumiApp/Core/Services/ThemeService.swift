import Foundation
import SwiftUI
import LumiUI

/// 将插件主题贡献登记到 ``LumiUIThemeRegistry``（Core ↔ LumiUI 桥梁）。
@MainActor
final class ThemeService {
    static let shared = ThemeService()

    private init() {}

    func syncFromPlugins(registry: LumiUIThemeRegistry = .shared) {
        let contributions = AppPluginVM.shared.getThemeContributions()
        do {
            try registry.replaceAll(contributions)
        } catch {
            fatalError(
                "Failed to register theme contributions: \(error). Enable at least one theme plugin."
            )
        }
    }
}

// MARK: - File Icon Theme

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

struct LumiFolderFileIcon {
    let collapsed: LumiFileIcon
    let expanded: LumiFileIcon

    func icon(isExpanded: Bool) -> LumiFileIcon {
        isExpanded ? expanded : collapsed
    }
}

protocol LumiFileIconThemeContributor: AnyObject {
    var id: String { get }
    var displayName: String { get }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon?
    func defaultFileIcon() -> LumiFileIcon
    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon
}

final class LumiRuleBasedFileIconThemeContributor: LumiFileIconThemeContributor {
    let id: String
    let displayName: String
    private let fileNameIcons: [String: LumiFileIcon]
    private let extensionIcons: [String: LumiFileIcon]
    private let folderIcons: [String: LumiFolderFileIcon]
    private let defaultFile: LumiFileIcon
    private let defaultFolder: LumiFolderFileIcon

    init(
        id: String,
        displayName: String,
        fileNameIcons: [String: LumiFileIcon] = [:],
        extensionIcons: [String: LumiFileIcon] = [:],
        folderIcons: [String: LumiFolderFileIcon] = [:],
        defaultFile: LumiFileIcon = .systemImage("doc"),
        defaultFolder: LumiFolderFileIcon = LumiFolderFileIcon(
            collapsed: .systemImage("folder"),
            expanded: .systemImage("folder.fill")
        )
    ) {
        self.id = id
        self.displayName = displayName
        self.fileNameIcons = fileNameIcons
        self.extensionIcons = extensionIcons
        self.folderIcons = folderIcons
        self.defaultFile = defaultFile
        self.defaultFolder = defaultFolder
    }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon? {
        if context.isDirectory {
            let name = context.fileName.lowercased()
            return folderIcons[name]?.icon(isExpanded: context.isExpanded)
        }

        if let icon = fileNameIcons[context.fileName.lowercased()] {
            return icon
        }

        if let icon = extensionIcons[context.fileExtension.lowercased()] {
            return icon
        }

        return nil
    }

    func defaultFileIcon() -> LumiFileIcon {
        defaultFile
    }

    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon {
        defaultFolder.icon(isExpanded: isExpanded)
    }
}

final class LumiDefaultFileIconThemeContributor: LumiFileIconThemeContributor {
    let id: String
    let displayName: String
    private let rules: LumiRuleBasedFileIconThemeContributor

    init(id: String = "lumi-default-file-icons", displayName: String = "Lumi File Icons") {
        self.id = id
        self.displayName = displayName
        self.rules = LumiFileIconThemeBuilder.make(
            id: id,
            displayName: displayName,
            defaultFile: .systemImage("doc"),
            defaultFolder: LumiFolderFileIcon(
                collapsed: .systemImage("folder"),
                expanded: .systemImage("folder.fill")
            )
        )
    }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon? {
        rules.icon(for: context)
    }

    func defaultFileIcon() -> LumiFileIcon {
        rules.defaultFileIcon()
    }

    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon {
        rules.defaultFolderIcon(isExpanded: isExpanded)
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

enum LumiFileIconThemeBuilder {
    static func make(
        id: String,
        displayName: String,
        defaultFile: LumiFileIcon,
        defaultFolder: LumiFolderFileIcon,
        extraFolders: [String: LumiFolderFileIcon] = [:],
        extraFileNames: [String: LumiFileIcon] = [:],
        extraExtensions: [String: LumiFileIcon] = [:]
    ) -> LumiRuleBasedFileIconThemeContributor {
        var folders = baseFolderIcons(defaultFolder: defaultFolder)
        folders.merge(normalizeFolderIcons(extraFolders)) { _, new in new }

        var fileNames = baseFileNameIcons()
        fileNames.merge(normalizeIcons(extraFileNames)) { _, new in new }

        var extensions = baseExtensionIcons()
        extensions.merge(normalizeIcons(extraExtensions)) { _, new in new }

        return LumiRuleBasedFileIconThemeContributor(
            id: id,
            displayName: displayName,
            fileNameIcons: fileNames,
            extensionIcons: extensions,
            folderIcons: folders,
            defaultFile: defaultFile,
            defaultFolder: defaultFolder
        )
    }

    static func folder(_ collapsed: String, _ expanded: String) -> LumiFolderFileIcon {
        LumiFolderFileIcon(collapsed: .systemImage(collapsed), expanded: .systemImage(expanded))
    }

    private static func baseFolderIcons(defaultFolder: LumiFolderFileIcon) -> [String: LumiFolderFileIcon] {
        [
            ".github": folder("chevron.left.forwardslash.chevron.right", "chevron.left.forwardslash.chevron.right"),
            "source": defaultFolder,
            "sources": defaultFolder,
            "src": defaultFolder,
            "test": folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
            "tests": folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
        ]
    }

    private static func baseFileNameIcons() -> [String: LumiFileIcon] {
        [
            ".gitignore": .systemImage("arrow.triangle.branch"),
            ".gitattributes": .systemImage("arrow.triangle.branch"),
            ".gitmodules": .systemImage("arrow.triangle.branch"),
            "package.swift": .systemImage("swift"),
            "package.json": .systemImage("shippingbox"),
            "readme": .systemImage("book"),
            "readme.md": .systemImage("book"),
            "readme.markdown": .systemImage("book"),
            "license": .systemImage("checkmark.seal"),
            "license.md": .systemImage("checkmark.seal"),
            "license.txt": .systemImage("checkmark.seal"),
            "makefile": .systemImage("hammer"),
        ]
    }

    private static func baseExtensionIcons() -> [String: LumiFileIcon] {
        [
            "swift": .systemImage("swift"),
            "m": .systemImage("c.circle"),
            "mm": .systemImage("c.circle"),
            "h": .systemImage("c.circle"),
            "json": .systemImage("curlybraces"),
            "yaml": .systemImage("list.bullet.indent"),
            "yml": .systemImage("list.bullet.indent"),
            "xml": .systemImage("chevron.left.forwardslash.chevron.right"),
            "plist": .systemImage("gearshape"),
            "xcworkspacedata": .systemImage("square.stack.3d.up"),
            "xcodeproj": .systemImage("hammer"),
            "png": .systemImage("photo"),
            "jpg": .systemImage("photo"),
            "jpeg": .systemImage("photo"),
            "gif": .systemImage("photo"),
            "webp": .systemImage("photo"),
            "svg": .systemImage("photo"),
            "icns": .systemImage("photo"),
            "ico": .systemImage("photo"),
            "pdf": .systemImage("doc.richtext"),
            "md": .systemImage("doc.text"),
            "markdown": .systemImage("doc.text"),
            "txt": .systemImage("doc.plaintext"),
            "rtf": .systemImage("doc.richtext"),
            "sh": .systemImage("terminal"),
            "bash": .systemImage("terminal"),
            "zsh": .systemImage("terminal"),
            "gitignore": .systemImage("arrow.triangle.branch"),
        ]
    }

    private static func normalizeIcons(_ icons: [String: LumiFileIcon]) -> [String: LumiFileIcon] {
        Dictionary(uniqueKeysWithValues: icons.map { ($0.key.lowercased(), $0.value) })
    }

    private static func normalizeFolderIcons(_ icons: [String: LumiFolderFileIcon]) -> [String: LumiFolderFileIcon] {
        Dictionary(uniqueKeysWithValues: icons.map { ($0.key.lowercased(), $0.value) })
    }
}
