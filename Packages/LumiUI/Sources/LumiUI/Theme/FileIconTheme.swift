import Foundation

public struct LumiFileIconContext {
    public let url: URL
    public let fileName: String
    public let fileExtension: String
    public let isDirectory: Bool
    public let isExpanded: Bool
    public let isSwiftPackageDirectory: Bool
    public let projectRootPath: String

    public init(
        url: URL,
        fileName: String,
        fileExtension: String,
        isDirectory: Bool,
        isExpanded: Bool,
        isSwiftPackageDirectory: Bool = false,
        projectRootPath: String
    ) {
        self.url = url
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.isDirectory = isDirectory
        self.isExpanded = isExpanded
        self.isSwiftPackageDirectory = isSwiftPackageDirectory
        self.projectRootPath = projectRootPath
    }
}

public enum LumiFileIcon {
    case systemImage(String)
    case assetImage(name: String, bundle: Bundle?)
}

public struct LumiFolderFileIcon {
    public let collapsed: LumiFileIcon
    public let expanded: LumiFileIcon

    public init(collapsed: LumiFileIcon, expanded: LumiFileIcon) {
        self.collapsed = collapsed
        self.expanded = expanded
    }

    public func icon(isExpanded: Bool) -> LumiFileIcon {
        isExpanded ? expanded : collapsed
    }
}

public protocol LumiFileIconThemeContributor: AnyObject {
    var id: String { get }
    var displayName: String { get }

    func icon(for context: LumiFileIconContext) -> LumiFileIcon?
    func defaultFileIcon() -> LumiFileIcon
    func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon
}

public final class LumiRuleBasedFileIconThemeContributor: LumiFileIconThemeContributor {
    public let id: String
    public let displayName: String
    private let fileNameIcons: [String: LumiFileIcon]
    private let extensionIcons: [String: LumiFileIcon]
    private let folderIcons: [String: LumiFolderFileIcon]
    private let defaultFile: LumiFileIcon
    private let defaultFolder: LumiFolderFileIcon

    public init(
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

    public func icon(for context: LumiFileIconContext) -> LumiFileIcon? {
        if context.isDirectory {
            if context.isSwiftPackageDirectory {
                return context.isExpanded ? .systemImage("shippingbox.fill") : .systemImage("shippingbox")
            }

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

    public func defaultFileIcon() -> LumiFileIcon {
        defaultFile
    }

    public func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon {
        defaultFolder.icon(isExpanded: isExpanded)
    }
}

public final class LumiDefaultFileIconThemeContributor: LumiFileIconThemeContributor {
    public let id: String
    public let displayName: String
    private let rules: LumiRuleBasedFileIconThemeContributor

    public init(id: String = "lumi-default-file-icons", displayName: String = "Lumi File Icons") {
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

    public func icon(for context: LumiFileIconContext) -> LumiFileIcon? {
        rules.icon(for: context)
    }

    public func defaultFileIcon() -> LumiFileIcon {
        rules.defaultFileIcon()
    }

    public func defaultFolderIcon(isExpanded: Bool) -> LumiFileIcon {
        rules.defaultFolderIcon(isExpanded: isExpanded)
    }

    public static func systemImageName(forFileExtension fileExtension: String) -> String? {
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

public enum LumiFileIconThemeBuilder {
    public static func make(
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

    public static func folder(_ collapsed: String, _ expanded: String) -> LumiFolderFileIcon {
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
