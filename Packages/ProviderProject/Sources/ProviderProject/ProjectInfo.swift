import Foundation

/// 项目信息
///
/// `ProjectProviding` 协议依赖的项目模型，随协议一起放在 ProviderProject 中，
/// 使 ProviderProject 成为 ProjectProviding 相关内容的唯一归属。
public struct ProjectInfo: Sendable, Codable, Equatable {
    public let name: String
    public let path: String
    public let language: String?

    public init(name: String, path: String, language: String? = nil) {
        self.name = name
        self.path = path
        self.language = language
    }
}

/// 当前项目变更的原因。
///
/// 调用 `ProjectProviding.openProject` 或 `closeProject` 时传入，
/// 便于观察者、日志和下游模块区分触发来源。
public enum ProjectChangeReason: Sendable, Equatable {
    /// 用户在界面上主动选择/打开项目。
    case userSelected
    /// 切换到绑定了项目的对话时自动切换。
    case conversationSwitch
    /// 应用启动时从持久化存储恢复上一次的项目。
    case appRestore
    /// 通过 Finder / Dock / URL Scheme 等外部方式打开。
    case externalOpen
    /// 当前项目被移除，回退到另一个项目或关闭。
    case projectRemoved
    /// 用户在设置中修改了项目路径。
    case settingsChange
}
