import LumiKernel
import LumiUI
import SwiftUI

/// Message List View (入口)
///
/// 根据当前会话的 verbosity 分发到对应的消息列表子视图:
/// - `.brief` (V1) → `MessageListV1View`
/// - `.standard` (V2) / `.detailed` (V3) → `MessageListV2View`
///
/// 本视图只负责通用状态判断(无会话选择)和路由分发,
/// loading / 空态 / 消息列表的滚动、分页、流式等全部逻辑由各子视图各自承担。
struct MessageListView: View {
    @ObservedObject var kernel: LumiKernel

    @LumiTheme private var theme

    init(kernel: LumiKernel) {
        self.kernel = kernel
    }

    private var selectedConversationID: UUID? {
        kernel.conversations?.selectedConversationID
    }

    private var verbosity: LumiResponseVerbosity {
        kernel.conversationManager?
            .verbosity(for: selectedConversationID) ?? .defaultVerbosity
    }

    var body: some View {
        Group {
            if selectedConversationID == nil {
                NoConversationSelectedView()
            } else {
                routedMessageList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
    }

    /// 根据 verbosity 路由到对应的消息列表子视图。
    @ViewBuilder
    private var routedMessageList: some View {
        switch verbosity {
        case .brief:
            MessageListV1View(kernel: kernel)
        case .standard, .detailed:
            MessageListV2View(kernel: kernel)
        }
    }
}
