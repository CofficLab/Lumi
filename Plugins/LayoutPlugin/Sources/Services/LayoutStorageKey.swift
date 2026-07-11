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

    // MARK: - 状态相关

    /// 当前激活的视图容器 ID
    public static let activeViewContainerID = "activeViewContainerID"

    /// 当前激活的视图容器图标（与 ID 分开存储）
    public static let activeViewContainerIcon = "activeViewContainerIcon"

    /// 当前激活的侧边栏 Rail Tab ID
    public static let activeRailTabID = "selectedAgentSidebarTabId"

    /// 当前激活的底部面板 Tab ID
    public static let activeBottomTabID = "activeBottomTabID"

    /// 底部面板可见性
    public static let bottomPanelVisible = "bottomPanelVisible"

    /// 聊天区可见性
    public static let chatSectionVisible = "chatSectionVisible"
}
