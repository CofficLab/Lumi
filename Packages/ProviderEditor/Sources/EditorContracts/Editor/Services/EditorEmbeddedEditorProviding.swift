import SwiftUI

/// 嵌入式编辑器选项（重构方案 §17.2）。
///
/// 由 Feature 插件（如 DatabaseManagerPlugin）描述其内嵌 SQL/代码编辑需求，
/// 与具体编辑器实现（`EditorService` / `EditorSource`）解耦。
public struct EditorEmbeddedEditorOptions {
    /// 语言标识（如 `"sql"`），由 Host 解析为语法/高亮上下文。
    public var languageID: String
    /// 是否允许编辑（false = 只读展示）。
    public var isEditable: Bool
    /// 是否允许选择文本。
    public var isSelectable: Bool
    /// 是否自动换行。
    public var wrapLines: Bool
    /// 是否显示行号槽。
    public var showGutter: Bool
    /// 字号；0 表示使用系统默认字号。
    public var fontSize: CGFloat
    /// 是否使用语法主题背景色。
    public var useThemeBackground: Bool

    public init(
        languageID: String,
        isEditable: Bool = true,
        isSelectable: Bool = true,
        wrapLines: Bool = true,
        showGutter: Bool = true,
        fontSize: CGFloat = 0,
        useThemeBackground: Bool = true
    ) {
        self.languageID = languageID
        self.isEditable = isEditable
        self.isSelectable = isSelectable
        self.wrapLines = wrapLines
        self.showGutter = showGutter
        self.fontSize = fontSize
        self.useThemeBackground = useThemeBackground
    }
}

/// 嵌入式编辑器能力（重构方案 §17.2）。
///
/// Feature 插件通过本能力在自身面板内嵌入一个具备语法高亮的
/// 代码/SQL 编辑器视图，而不直接依赖编辑器实现层。
/// Host（EditorHostPlugin）负责用真实编辑器实现本协议；
/// 未注册时消费方可退回纯 SwiftUI 编辑器。
///
/// 本协议属于 KernelLumi 的 UI 契约分区，允许使用 `AnyView`。
@MainActor
public protocol EditorEmbeddedEditorProviding: AnyObject {
    /// 创建嵌入式编辑器视图。
    ///
    /// - Parameters:
    ///   - text: 文本内容的双向绑定。
    ///   - options: 外观与行为选项。
    /// - Returns: 编辑器视图；Host 未就绪时应返回可用占位，绝不返回 nil。
    func makeEmbeddedEditorView(text: Binding<String>, options: EditorEmbeddedEditorOptions) -> AnyView
}
