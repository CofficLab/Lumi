import Foundation

// MARK: - 配置模型

/// 设置项键（如 `"editor.tabSize"`）。
public struct EditorSettingKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// 设置作用域。优先级：默认值 < 插件默认 < 用户 < 工作区 < 语言覆盖。
public enum EditorSettingScope: Equatable, Hashable, Sendable {
    /// 插件声明的默认值。
    case defaults

    /// 用户级设置。
    case user

    /// 工作区级设置。
    case workspace

    /// 某语言的覆盖设置。
    case languageOverride(String)
}

/// 设置值：有限的中立值类型。
public enum EditorSettingValue: Equatable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case stringArray([String])
}

/// 配置解析上下文（当前文档语言等）。
public struct EditorConfigurationContext: Equatable, Sendable {
    public let languageID: String?

    public init(languageID: String? = nil) {
        self.languageID = languageID
    }
}

/// 一份设置键值快照（仅含各作用域合并前的原始值，解析走 `resolvedValue`）。
public struct EditorConfigurationSnapshot: Equatable, Sendable {
    /// 用户作用域键值。
    public let userValues: [EditorSettingKey: EditorSettingValue]

    /// 工作区作用域键值。
    public let workspaceValues: [EditorSettingKey: EditorSettingValue]

    /// 语言覆盖键值（外层 key 为 language ID）。
    public let languageOverrides: [String: [EditorSettingKey: EditorSettingValue]]

    public init(
        userValues: [EditorSettingKey: EditorSettingValue] = [:],
        workspaceValues: [EditorSettingKey: EditorSettingValue] = [:],
        languageOverrides: [String: [EditorSettingKey: EditorSettingValue]] = [:]
    ) {
        self.userValues = userValues
        self.workspaceValues = workspaceValues
        self.languageOverrides = languageOverrides
    }

    /// 按作用域优先级（语言覆盖 > 工作区 > 用户）查找某键的原始值。
    public func rawValue(for key: EditorSettingKey, context: EditorConfigurationContext) -> EditorSettingValue? {
        if let languageID = context.languageID,
           let override = languageOverrides[languageID]?[key] {
            return override
        }
        if let workspace = workspaceValues[key] {
            return workspace
        }
        return userValues[key]
    }
}
