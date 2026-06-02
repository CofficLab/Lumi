import SwiftUI
import LumiUI

/// 对话时间线空状态视图
public struct ConversationTimelineEmptyState: View {
    public var body: some View {
        AppEmptyState(
            icon: "tray",
            title: "暂无消息"
        )
    }
}
