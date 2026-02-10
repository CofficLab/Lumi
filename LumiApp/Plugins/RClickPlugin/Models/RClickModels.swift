import Foundation

public enum RClickActionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case newFile = "newFile" // Acts as a submenu or category
    case copyPath = "copyPath"
    case openInTerminal = "openInTerminal"
    case openInVSCode = "openInVSCode"
    case deleteFile = "deleteFile"
    case hideFile = "hideFile"
    case showHiddenFiles = "showHiddenFiles"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .newFile: return "New File"
        case .copyPath: return "Copy Path"
        case .openInTerminal: return "Open in Terminal"
        case .openInVSCode: return "Open in VS Code"
        case .deleteFile: return "Delete File"
        case .hideFile: return "Hide File"
        case .showHiddenFiles: return "Show Hidden Files"
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
        case .showHiddenFiles: return "eye"
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
}

public struct RClickConfig: Codable, Equatable, Sendable {
    public var items: [RClickMenuItem]
    public var fileTemplates: [NewFileTemplate]
    
    public static let `default` = RClickConfig(
        items: [
            RClickMenuItem(type: .openInVSCode),
            RClickMenuItem(type: .openInTerminal),
            RClickMenuItem(type: .copyPath),
            RClickMenuItem(type: .newFile),
            RClickMenuItem(type: .deleteFile, isEnabled: false),
            RClickMenuItem(type: .hideFile, isEnabled: false),
            RClickMenuItem(type: .showHiddenFiles, isEnabled: false)
        ],
        fileTemplates: [
            NewFileTemplate(name: "Text File", extensionName: "txt"),
            NewFileTemplate(name: "Markdown", extensionName: "md"),
            NewFileTemplate(name: "JSON", extensionName: "json", content: "{\n\t\n}")
        ]
    )
}
