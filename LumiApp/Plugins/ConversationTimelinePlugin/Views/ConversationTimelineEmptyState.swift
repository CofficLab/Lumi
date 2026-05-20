import SwiftUI
import LumiUI

/// 对话时间线空状态视图
struct ConversationTimelineEmptyState: View {
    var body: some View {
        AppEmptyState(
            icon: "tray",
            title: "暂无消息"
        )
    }
}
