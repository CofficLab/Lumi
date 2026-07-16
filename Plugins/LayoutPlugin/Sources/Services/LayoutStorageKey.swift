import LumiCoreKit

/// 布局存储键定义
///
/// 集中管理所有持久化存储的 key，避免硬编码字符串分散在各处。
///
/// ## 尺寸 key 格式
/// v2 起，分栏尺寸存储为 **divider 位置**（NSSplitView 原生粒度），
/// key 格式：`Layout.Position.<id>.<role>[.<layoutSuffix>].<dividerIndex>`
///
/// - `Layout.Position.LumiEditor.Rail.0`
/// - `Layout.Position.LumiEditor.ChatSection.narrow.0`
/// - `Layout.Position.LumiEditor.BottomPanel.0`
public enum LayoutStorageKey {
    // MARK: - 尺寸相关

    public static func railDivider(viewContainerID: String) -> String {
        "Layout.Position.\(viewContainerID).Rail.0"
    }

    public static func chatSectionDivider(
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> String {
        "Layout.Position.\(viewContainerID).ChatSection.\(layout.persistenceKeySuffix).0"
    }

    public static func bottomPanelDivider(viewContainerID: String) -> String {
        "Layout.Position.\(viewContainerID).BottomPanel.0"
    }

    /// 指定视图容器的底部面板选中 tab。
    /// 与 divider 不同，tab 无"分隔条序号"概念，因此不带 `.0` 后缀；
    /// key 形如 `Layout.Position.LumiEditor.BottomTab`。
    public static func bottomTabID(viewContainerID: String) -> String {
        "Layout.Position.\(viewContainerID).BottomTab"
    }

    // MARK: - 状态相关

    /// 当前激活的视图容器 ID
    public static let activeViewContainerID = "activeViewContainerID"

    /// 当前激活的视图容器图标（与 ID 分开存储）
    public static let activeViewContainerIcon = "activeViewContainerIcon"

    /// 当前激活的侧边栏 Rail Tab ID
    public static let activeRailTabID = "selectedAgentSidebarTabId"

    /// v1 历史遗留：当时底部面板 tab 是全局标量，存在此顶层 key 下。
    /// v2 起改为 per-container（见 `bottomTabID(viewContainerID:)`），启动时由迁移逻辑读出后清除此 key。
    public static let legacyActiveBottomTabID = "activeBottomTabID"

    /// 底部面板可见性
    public static let bottomPanelVisible = "bottomPanelVisible"

    /// 聊天区可见性
    public static let chatSectionVisible = "chatSectionVisible"
}
