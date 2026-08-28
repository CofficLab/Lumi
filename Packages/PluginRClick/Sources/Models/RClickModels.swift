import Foundation

enum RClickPluginRuntimeBridge {
    nonisolated(unsafe) static var dataRootDirectory: URL?
    static var fallbackRootDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
    }
}

public enum RClickActionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case newFile = "newFile" // Acts as a submenu or category
    case copyPath = "copyPath"
    case openInTerminal = "openInTerminal"
    case openInVSCode = "openInVSCode"
    case deleteFile = "deleteFile"
    case hideFile = "hideFile"
    case unhideFile = "unhideFile"
    case showHiddenFiles = "showHiddenFiles"
    /// Persisted as `listHiddenFiles` for compatibility with existing configs.
    case hideHiddenFiles = "listHiddenFiles"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newFile: return LumiPluginLocalization.string("New File", bundle: .module)
        case .copyPath: return LumiPluginLocalization.string("Copy Path", bundle: .module)
        case .openInTerminal: return LumiPluginLocalization.string("Open in Terminal", bundle: .module)
        case .openInVSCode: return LumiPluginLocalization.string("Open in VS Code", bundle: .module)
        case .deleteFile: return LumiPluginLocalization.string("Delete File", bundle: .module)
        case .hideFile: return LumiPluginLocalization.string("Hide File", bundle: .module)
        case .unhideFile: return LumiPluginLocalization.string("Unhide File", bundle: .module)
        case .showHiddenFiles: return LumiPluginLocalization.string("Show Hidden Files", bundle: .module)
        case .hideHiddenFiles: return LumiPluginLocalization.string("Do Not Show Hidden Files", bundle: .module)
        }
    }

    public var iconName: String {
        switch self {
        case .newFile: return "doc.badge.plus"
        case .copyPath: return "doc.on.doc"
        case .openInTerminal: return "apple.terminal"
        case .openInVSCode: return "chevron.left.forwardslash.chevron.right"
        case .deleteFile: return "trash"
        case .hideFile: return "eye.slash"
        case .unhideFile: return "eye"
        case .showHiddenFiles: return "eye"
        case .hideHiddenFiles: return "eye.slash"
        }
    }
}

public struct RClickMenuItem: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var type: RClickActionType
    public var customTitle: String?
    public var isEnabled: Bool
    
    public var title: String {
        return customTitle ?? type.title
    }
    
    public init(id: String = UUID().uuidString, type: RClickActionType, customTitle: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.type = type
        self.customTitle = customTitle
        self.isEnabled = isEnabled
    }
}

public struct NewFileTemplate: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var extensionName: String
    public var content: String
    public var isEnabled: Bool
    
    public init(id: String = UUID().uuidString, name: String, extensionName: String, content: String = "", isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.extensionName = extensionName
        self.content = content
        self.isEnabled = isEnabled
    }

    public var normalizedForStorage: NewFileTemplate? {
        guard let normalizedName = Self.normalizedName(name),
              let normalizedExtension = Self.normalizedExtension(extensionName) else {
            return nil
        }

        var normalized = self
        normalized.name = normalizedName
        normalized.extensionName = normalizedExtension
        return normalized
    }

    public static func normalizedName(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 128 else { return nil }
        guard !trimmed.contains("/") && !trimmed.contains(":") else { return nil }
        guard trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return trimmed
    }

    public static func normalizedExtension(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutLeadingDots = trimmed.drop(while: { $0 == "." })
        guard !withoutLeadingDots.isEmpty, withoutLeadingDots.count <= 32 else { return nil }
        guard withoutLeadingDots.allSatisfy(Self.isValidExtensionCharacter) else { return nil }
        return String(withoutLeadingDots)
    }

    public static func isValidName(_ value: String) -> Bool {
        normalizedName(value) != nil
    }

    public static func isValidExtension(_ value: String) -> Bool {
        normalizedExtension(value) != nil
    }

    private static func isValidExtensionCharacter(_ character: Character) -> Bool {
        guard character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first else {
            return false
        }

        return (scalar.value >= 48 && scalar.value <= 57)
            || (scalar.value >= 65 && scalar.value <= 90)
            || (scalar.value >= 97 && scalar.value <= 122)
            || scalar == "-"
            || scalar == "_"
    }
}

public struct RClickConfig: Codable, Equatable, Sendable {
    public var items: [RClickMenuItem]
    public var fileTemplates: [NewFileTemplate]

    public var normalizedForStorage: RClickConfig {
        let existingTypes = Set(items.map(\.type))
        let missingDefaultItems = Self.default.items.filter { !existingTypes.contains($0.type) }

        return RClickConfig(
            items: items + missingDefaultItems,
            fileTemplates: fileTemplates.compactMap(\.normalizedForStorage)
        )
    }
    
    public static let `default` = RClickConfig(
        items: [
            RClickMenuItem(type: .openInVSCode),
            RClickMenuItem(type: .openInTerminal),
            RClickMenuItem(type: .copyPath),
            RClickMenuItem(type: .newFile),
            RClickMenuItem(type: .deleteFile, isEnabled: false),
            RClickMenuItem(type: .hideFile, isEnabled: false),
            RClickMenuItem(type: .unhideFile, isEnabled: false),
            RClickMenuItem(type: .showHiddenFiles, isEnabled: false),
            RClickMenuItem(type: .hideHiddenFiles, isEnabled: false)
        ],
        fileTemplates: [
            NewFileTemplate(name: "Text File", extensionName: "txt"),
            NewFileTemplate(name: "Markdown", extensionName: "md"),
            NewFileTemplate(name: "JSON", extensionName: "json", content: "{\n\t\n}")
        ]
    )
}
