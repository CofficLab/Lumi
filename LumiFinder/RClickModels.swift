import Foundation

// MARK: - Models

/// 右键菜单操作类型
enum RClickActionType: String, Codable {
    case newFile = "newFile"
    case copyPath = "copyPath"
    case openInTerminal = "openInTerminal"
    case openInVSCode = "openInVSCode"
    case deleteFile = "deleteFile"
    case hideFile = "hideFile"
}

/// 右键菜单项配置
struct RClickMenuItem: Codable {
    var id: String
    var type: RClickActionType
    var customTitle: String?
    var isEnabled: Bool
}

/// 新建文件模板
struct NewFileTemplate: Codable {
    var id: String
    var name: String
    var extensionName: String
    var content: String
    var isEnabled: Bool
}

/// 右键菜单配置
struct RClickConfig: Codable {
    var items: [RClickMenuItem]
    var fileTemplates: [NewFileTemplate]?
}
