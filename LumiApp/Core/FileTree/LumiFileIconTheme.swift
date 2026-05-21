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
        self.rules = LumiFileIconThemeCatalog.make(
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

enum LumiFileIconThemeCatalog {
    static func lumi() -> any LumiFileIconThemeContributor {
        make(
            id: "lumi-file-icons",
            displayName: "Lumi File Icons",
            defaultFile: .systemImage("doc.text"),
            defaultFolder: folder("folder", "folder.fill"),
            extraExtensions: [
                "swift": .systemImage("swift"),
                "md": .systemImage("text.alignleft"),
                "json": .systemImage("curlybraces"),
            ]
        )
    }

    static func midnight() -> any LumiFileIconThemeContributor {
        make(
            id: "midnight-file-icons",
            displayName: "Midnight File Icons",
            defaultFile: .systemImage("doc"),
            defaultFolder: folder("folder", "folder.fill"),
            extraExtensions: [
                "md": .systemImage("text.alignleft"),
                "markdown": .systemImage("text.alignleft"),
                "json": .systemImage("curlybraces.square"),
            ]
        )
    }

    static func aurora() -> any LumiFileIconThemeContributor {
        make(
            id: "aurora-file-icons",
            displayName: "Aurora File Icons",
            defaultFile: .systemImage("sparkles"),
            defaultFolder: folder("folder.badge.plus", "folder.fill.badge.plus"),
            extraExtensions: [
                "png": .systemImage("photo.on.rectangle"),
                "jpg": .systemImage("photo.on.rectangle"),
                "jpeg": .systemImage("photo.on.rectangle"),
                "svg": .systemImage("camera.filters"),
            ]
        )
    }

    static func nebula() -> any LumiFileIconThemeContributor {
        make(
            id: "nebula-file-icons",
            displayName: "Nebula File Icons",
            defaultFile: .systemImage("circle.hexagongrid"),
            defaultFolder: folder("folder.badge.questionmark", "folder.fill.badge.questionmark"),
            extraExtensions: [
                "swift": .systemImage("atom"),
                "json": .systemImage("circle.hexagongrid.fill"),
            ]
        )
    }

    static func void() -> any LumiFileIconThemeContributor {
        make(
            id: "void-file-icons",
            displayName: "Void File Icons",
            defaultFile: .systemImage("doc.fill"),
            defaultFolder: folder("archivebox", "archivebox.fill"),
            extraFileNames: [
                "readme": .systemImage("doc.text.fill"),
                "readme.md": .systemImage("doc.text.fill"),
                "readme.markdown": .systemImage("doc.text.fill"),
            ]
        )
    }

    static func spring() -> any LumiFileIconThemeContributor {
        make(
            id: "spring-file-icons",
            displayName: "Spring File Icons",
            defaultFile: .systemImage("leaf"),
            defaultFolder: folder("folder.badge.plus", "folder.fill.badge.plus"),
            extraExtensions: [
                "md": .systemImage("leaf"),
                "markdown": .systemImage("leaf"),
                "txt": .systemImage("doc.text"),
            ]
        )
    }

    static func summer() -> any LumiFileIconThemeContributor {
        make(
            id: "summer-file-icons",
            displayName: "Summer File Icons",
            defaultFile: .systemImage("sun.max"),
            defaultFolder: folder("folder.badge.person.crop", "folder.fill.badge.person.crop"),
            extraExtensions: [
                "png": .systemImage("sun.max"),
                "jpg": .systemImage("sun.max"),
                "jpeg": .systemImage("sun.max"),
                "pdf": .systemImage("doc.richtext.fill"),
            ]
        )
    }

    static func autumn() -> any LumiFileIconThemeContributor {
        make(
            id: "autumn-file-icons",
            displayName: "Autumn File Icons",
            defaultFile: .systemImage("doc.text.image"),
            defaultFolder: folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
            extraExtensions: [
                "yaml": .systemImage("list.bullet.rectangle"),
                "yml": .systemImage("list.bullet.rectangle"),
                "plist": .systemImage("gearshape.2"),
            ]
        )
    }

    static func winter() -> any LumiFileIconThemeContributor {
        make(
            id: "winter-file-icons",
            displayName: "Winter File Icons",
            defaultFile: .systemImage("snowflake"),
            defaultFolder: folder("folder.badge.questionmark", "folder.fill.badge.questionmark"),
            extraExtensions: [
                "sh": .systemImage("terminal.fill"),
                "bash": .systemImage("terminal.fill"),
                "zsh": .systemImage("terminal.fill"),
            ]
        )
    }

    static func orchard() -> any LumiFileIconThemeContributor {
        make(
            id: "orchard-file-icons",
            displayName: "Orchard File Icons",
            defaultFile: .systemImage("apple.logo"),
            defaultFolder: folder("tray", "tray.fill"),
            extraExtensions: [
                "swift": .systemImage("swift"),
                "h": .systemImage("h.square"),
            ]
        )
    }

    static func mountain() -> any LumiFileIconThemeContributor {
        make(
            id: "mountain-file-icons",
            displayName: "Mountain File Icons",
            defaultFile: .systemImage("mountain.2"),
            defaultFolder: folder("folder.badge.minus", "folder.fill.badge.minus"),
            extraFileNames: [
                "makefile": .systemImage("hammer.fill"),
            ]
        )
    }

    static func river() -> any LumiFileIconThemeContributor {
        make(
            id: "river-file-icons",
            displayName: "River File Icons",
            defaultFile: .systemImage("water.waves"),
            defaultFolder: folder("externaldrive", "externaldrive.fill"),
            extraExtensions: [
                "xml": .systemImage("point.3.connected.trianglepath.dotted"),
                "json": .systemImage("point.3.connected.trianglepath.dotted"),
            ]
        )
    }

    static func github() -> any LumiFileIconThemeContributor {
        make(
            id: "github-file-icons",
            displayName: "GitHub File Icons",
            defaultFile: .systemImage("doc"),
            defaultFolder: folder("folder", "folder.fill"),
            extraFolders: [
                ".github": folder("point.3.connected.trianglepath.dotted", "point.3.connected.trianglepath.dotted"),
            ],
            extraFileNames: [
                ".gitignore": .systemImage("arrow.triangle.branch"),
                ".gitattributes": .systemImage("arrow.triangle.branch"),
                ".gitmodules": .systemImage("arrow.triangle.branch"),
            ]
        )
    }

    static func vscodeDark() -> any LumiFileIconThemeContributor {
        make(
            id: "vscode-dark-file-icons",
            displayName: "VS Code Dark File Icons",
            defaultFile: .systemImage("doc.text"),
            defaultFolder: folder("folder", "folder.fill"),
            extraFileNames: [
                "package.json": .systemImage("shippingbox.fill"),
                "package.swift": .systemImage("swift"),
            ],
            extraExtensions: [
                "json": .systemImage("curlybraces.square.fill"),
                "md": .systemImage("doc.richtext"),
                "markdown": .systemImage("doc.richtext"),
            ]
        )
    }

    static func vscodeLight() -> any LumiFileIconThemeContributor {
        make(
            id: "vscode-light-file-icons",
            displayName: "VS Code Light File Icons",
            defaultFile: .systemImage("doc.plaintext"),
            defaultFolder: folder("folder", "folder.fill"),
            extraExtensions: [
                "json": .systemImage("curlybraces.square"),
                "md": .systemImage("book.pages"),
                "markdown": .systemImage("book.pages"),
            ]
        )
    }

    static func oneDark() -> any LumiFileIconThemeContributor {
        make(
            id: "one-dark-file-icons",
            displayName: "One Dark File Icons",
            defaultFile: .systemImage("doc.circle"),
            defaultFolder: folder("folder.circle", "folder.circle.fill"),
            extraExtensions: [
                "swift": .systemImage("swift"),
                "json": .systemImage("curlybraces"),
            ]
        )
    }

    static func dracula() -> any LumiFileIconThemeContributor {
        make(
            id: "dracula-file-icons",
            displayName: "Dracula File Icons",
            defaultFile: .systemImage("doc.fill"),
            defaultFolder: folder("folder.badge.gearshape", "folder.fill.badge.gearshape"),
            extraFileNames: [
                "license": .systemImage("checkmark.seal.fill"),
                "license.md": .systemImage("checkmark.seal.fill"),
                "license.txt": .systemImage("checkmark.seal.fill"),
            ]
        )
    }

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

    private static func folder(_ collapsed: String, _ expanded: String) -> LumiFolderFileIcon {
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
