import Foundation

/// 项目类型推断的结果。
///
/// 一次推断同时给出**给人和给机器看**的两份描述：
/// - `labels`：直接可展示的类型名，例如 `Swift (Xcode / SPM)`；
/// - `symbolName`：对应的 SF Symbol 名，供 UI 用图标表达「这是个什么项目」。
///
/// 检测逻辑原先只存在于 `PluginProjectOverview`，且只产出字符串给 agent 工具用。
/// 抽到本包后，agent 工具与聊天空态共用同一份判定，不会出现「工具说是 Swift，
/// 空态说是 Node」这种分叉。
public struct ProjectTypeDescriptor: Sendable, Equatable {
    /// 命中的类型名，按判定顺序排列。空数组表示无法识别。
    public let labels: [String]
    /// 类型图标。无法识别时为 `folder`，识别出多种类型时取第一种的图标。
    public let symbolName: String
    /// 无法识别出任何类型。
    public var isUnknown: Bool { labels.isEmpty }

    public init(labels: [String], symbolName: String) {
        self.labels = labels
        self.symbolName = symbolName
    }

    /// 无法识别时的描述。
    public static let unknown = ProjectTypeDescriptor(labels: [], symbolName: "folder")

    /// 面向展示的类型串：多个类型用 `; ` 连接，未知时返回 nil。
    public var displayText: String? {
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: "; ")
    }
}
