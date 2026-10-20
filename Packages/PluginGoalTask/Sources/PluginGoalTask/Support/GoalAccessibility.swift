import Foundation

/// Goal 插件各界面元素的无障碍标识符。
///
/// ## 为什么需要它
///
/// Goal 侧边栏与弹窗里的文案大量是插件内硬编码的中文字面量（如「继续」、
/// 「正在生成回复…」），不走 `String(localized:)`，因此**不随 `-AppleLanguages` 变化**。
/// UI 测试若按文案定位，就会在中英文环境之间反复失效；按标识符定位则与语言无关。
///
/// ## 维护约定
///
/// - UI 测试 target 无法 import 插件模块，需在 `LumiUITests/` 侧复述同一组常量，
///   改动必须两边同步。
/// - 命名沿用 `lumi.<模块>.<元素>` 约定。
///
/// ## 不要给容器挂标识符
///
/// SwiftUI 会把容器上的 `accessibilityIdentifier` **继承给它的直接子元素**，
/// 并覆盖子元素自己的标识符。实测：给编辑器根 `VStack` 挂上标识符后，
/// 它的「取消 / 保存」按钮拿到的都是根标识符，而不是各自的
/// `…custom-provider.cancel` / `…custom-provider.save`——按后者定位永远找不到。
///
/// 因此这里的标识符**只挂在叶子控件上**（Text / Image / Button），
/// 不给 `VStack` / `HStack` / `ScrollView` 挂。
///
/// 同理，**列表里的每一行会共用同一个标识符**：UI 测试要按数量统计时，
/// 用 `matching(identifier:)` 取出全部匹配项，而不是 `staticTexts[identifier]`。
///
/// ## 读文本要走 `value`，不是 `label`
///
/// SwiftUI 的 `Text` 在 macOS 无障碍树里把正文放在 **`value`** 上，`label` 是空串。
/// 实测：带 `accessibilityIdentifier` 的 `Text` 元素 `label` 为 `""`、
/// `value` 才是正文。因此 UI 测试读这些元素的文本时必须取 `value`
/// （基类 `element(anyLabelOf:)` 同时匹配两者，是另一条可用路径）。
public enum GoalAccessibility {
    // MARK: - 侧边栏（聊天面板左栏）

    /// 有活跃 Goal 时侧边栏标题栏里的目标标题。
    public static let goalTitle = "lumi.goal.title"

    /// 无活跃 Goal 时侧边栏标题栏的占位标题。
    ///
    /// 与 `goalTitle` 分开：占位标题是 `Label`，SwiftUI 不保证把它暴露成
    /// `staticText`（实测在 macOS 上落在别的元素类型上），
    /// 单独一个标识符才能让 UI 测试区分这两种形态。
    public static let goalTitlePlaceholder = "lumi.goal.title-placeholder"

    /// 标题栏右侧的进度文本（如「2/5」）。
    public static let goalProgress = "lumi.goal.progress"

    /// 打开描述弹窗的按钮。
    public static let descriptionButton = "lumi.goal.description-button"

    /// 「在新对话中继续」按钮。
    public static let forkButton = "lumi.goal.fork-button"

    /// 折叠 / 展开侧边栏的按钮。
    public static let collapseButton = "lumi.goal.collapse-button"

    /// 阻塞原因卡片里的原因文本。
    public static let blockedReason = "lumi.goal.blocked-reason"

    // MARK: - 任务列表

    /// 任务行标题。**每一行共用此标识符**，按数量统计时用 `matching(identifier:)`。
    public static let taskTitle = "lumi.goal.task-title"

    /// 任务行左侧的状态图标。**每一行共用此标识符**。
    public static let taskStatusIcon = "lumi.goal.task-status-icon"

    /// 任务行右侧的并行组标签（如 `[A]`）。
    public static let taskGroupBadge = "lumi.goal.task-group"

    // MARK: - 工具栏弹窗

    /// 工具栏上的 Goal 按钮（带进度角标）。
    public static let toolbarButton = "lumi.goal.toolbar-button"

    /// 工具栏弹窗的标题栏。
    public static let popoverHeader = "lumi.goal.popover-header"

    /// 工具栏弹窗标题栏里的 Goal 数量。
    public static let popoverCount = "lumi.goal.popover-count"

    /// 工具栏弹窗的空态文案。
    public static let popoverEmptyText = "lumi.goal.popover-empty"

    /// 工具栏弹窗里单个 Goal 的标题。**每一行共用此标识符**。
    public static let popoverGoalTitle = "lumi.goal.popover-goal-title"

    /// 工具栏弹窗里单个 Goal 的完成度（如「2/5」）。**每一行共用此标识符**。
    public static let popoverGoalProgress = "lumi.goal.popover-goal-progress"

    /// 工具栏弹窗里的「在新对话中继续」按钮。**每一行共用此标识符**。
    public static let popoverForkButton = "lumi.goal.popover-fork-button"

    /// 工具栏弹窗展开后的任务标题。**每一行共用此标识符**。
    public static let popoverTaskTitle = "lumi.goal.popover-task-title"

    // MARK: - 描述弹窗

    /// 描述弹窗里的正文。
    public static let descriptionText = "lumi.goal.description-text"

    // MARK: - 「在新对话中继续」确认弹窗

    /// 确认弹窗顶部的目标标题。
    public static let forkPopoverTitle = "lumi.goal.fork-popover-title"

    /// 确认弹窗里未完成任务的标题。**每一行共用此标识符**。
    public static let forkPopoverTaskTitle = "lumi.goal.fork-popover-task-title"

    /// 确认弹窗底部的确认按钮。
    public static let forkPopoverConfirm = "lumi.goal.fork-popover-confirm"
}
