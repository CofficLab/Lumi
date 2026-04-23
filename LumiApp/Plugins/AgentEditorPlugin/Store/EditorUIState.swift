import Foundation
import AppKit
import MagicKit
import CodeEditSourceEditor

/// 编辑器 UI 状态
///
/// 纯 UI 配置容器，与业务逻辑解耦。
/// 所有属性都是 `@Published`，可直接绑定到视图。
///
/// ## 职责范围
/// - 字体大小、Tab 宽度、空格/Tab 选择
/// - 自动换行、Minimap、行号、代码折叠显示
/// - 主题预设与当前主题
/// - 光标位置（行/列）
/// - 多光标编辑开关
///
/// ## 线程模型
/// 标记 `@MainActor`，所有属性更新在主线程执行。
@MainActor
final class EditorUIState: ObservableObject {

    // MARK: - 字体与缩进

    /// 字体大小
    @Published var fontSize: Double = 13.0

    /// Tab 宽度
    @Published var tabWidth: Int = 4

    /// 是否使用空格替代 Tab
    @Published var useSpaces: Bool = true

    // MARK: - 显示选项

    /// 是否自动换行
    @Published var wrapLines: Bool = true

    /// 是否显示 Minimap
    @Published var showMinimap: Bool = true

    /// 是否显示行号
    @Published var showGutter: Bool = true

    /// 是否显示代码折叠
    @Published var showFoldingRibbon: Bool = true

    /// 是否显示 Minimap（已废弃，使用 showMinimap）
    @available(*, deprecated, message: "Use showMinimap")
    var minimapEnabled: Bool {
        get { showMinimap }
        set { showMinimap = newValue }
    }

    // MARK: - 主题

    /// 当前主题预设
    @Published var themePreset: EditorThemeAdapter.PresetTheme = .xcodeDark

    /// 当前主题（缓存，避免每次重建）
    @Published var currentTheme: EditorTheme?

    // MARK: - 光标

    /// 当前行号（1-based）
    @Published var cursorLine: Int = 1

    /// 当前列号（1-based）
    @Published var cursorColumn: Int = 1

    // MARK: - 多光标

    /// 多光标编辑状态
    @Published var multiCursorState = MultiCursorState()

    // MARK: - 初始化

    init() {
        currentTheme = EditorThemeAdapter.theme(from: themePreset)
    }

    // MARK: - 重置

    func reset() {
        fontSize = 13.0
        tabWidth = 4
        useSpaces = true
        wrapLines = true
        showMinimap = true
        showGutter = true
        showFoldingRibbon = true
        themePreset = .xcodeDark
        currentTheme = EditorThemeAdapter.theme(from: .xcodeDark)
        cursorLine = 1
        cursorColumn = 1
        multiCursorState = MultiCursorState()
    }
}
