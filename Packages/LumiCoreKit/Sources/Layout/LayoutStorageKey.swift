import Foundation
import LumiCoreKit

/// 布局存储键枚举
public enum LayoutStorageKey {
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
}
