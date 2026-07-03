import LumiCoreKit

/// 布局存储键定义
///
/// 集中管理所有持久化存储的 key，避免硬编码字符串分散在各处。
public enum LayoutStorageKey {
    // MARK: - 尺寸相关

    public static func railWidth(viewContainerID: String) -> String {
        "Layout.Width.\(viewContainerID).Rail"
    }

    public static func chatSectionWidth(
        viewContainerID: String,
        layout: LumiChatSectionLayout
    ) -> String {
        "Layout.Width.\(viewContainerID).ChatSection.\(layout.persistenceKeySuffix)"
    }

    public static func bottomPanelHeight(viewContainerID: String) -> String {
        "Layout.Height.\(viewContainerID).BottomPanel"
    }

    // MARK: - 状态相关

    /// 当前激活的视图容器 ID
    public static let activeViewContainerID = "activeViewContainerID"

    /// 当前激活的侧边栏 Rail Tab ID
    public static let activeRailTabID = "selectedAgentSidebarTabId"

    /// 当前激活的底部面板 Tab ID
    public static let activeBottomTabID = "activeBottomTabID"

    /// 底部面板可见性
    public static let bottomPanelVisible = "bottomPanelVisible"

    /// 聊天区可见性
    public static let chatSectionVisible = "chatSectionVisible"
}
