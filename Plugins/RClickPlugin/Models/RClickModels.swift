import Foundation

public enum RClickActionType: String, Codable, CaseIterable, Identifiable, Sendable {
    case newFile = "newFile"
    case copyPath = "copyPath"
    case openInTerminal = "openInTerminal"
    case openInVSCode = "openInVSCode"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .newFile: return "New File"
        case .copyPath: return "Copy Path"
        case .openInTerminal: return "Open in Terminal"
        case .openInVSCode: return "Open in VS Code"
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

public struct RClickConfig: Codable, Equatable, Sendable {
    public var items: [RClickMenuItem]
    
    public static let `default` = RClickConfig(items: [
        RClickMenuItem(type: .newFile),
        RClickMenuItem(type: .copyPath),
        RClickMenuItem(type: .openInTerminal),
        RClickMenuItem(type: .openInVSCode)
    ])
}
