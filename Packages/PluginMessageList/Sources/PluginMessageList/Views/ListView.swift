import Combine
import Foundation
import LumiUI
import ProviderConversation
import SwiftUI

/// Message List View (入口)
///
/// 根据当前会话的 verbosity 分发到对应的消息列表子视图：
/// - `.brief` (V1) → `ListV1View`
/// - `.standard` (V2) → `ListV2View`
/// - `.detailed` (V3) → `ListV3View`（显示思考内容）
///
/// 本视图只负责通用状态判断（无会话选择）和路由分发，
/// loading / 空态 / 消息列表的滚动、分页、流式等全部逻辑由各子视图各自承担。
struct ListView: View {
    let services: MessageListServices

    @LumiTheme private var theme

    /// 快照 + 事件刷新（同 ChatHeaderView 模式）：不订阅容器的 objectWillChange。
    /// init 同步读初值，避免首次渲染前路由错位；之后由事件驱动更新。
    @State private var selectedConversationID: UUID?
    @State private var verbosity: LumiResponseVerbosity = .defaultVerbosity

    init(services: MessageListServices) {
        self.services = services
        _selectedConversationID = State(initialValue: services.selectedConversationID)
        _verbosity = State(
            initialValue: services.verbosity(for: services.selectedConversationID)
        )
    }

    var body: some View {
        Group {
            if selectedConversationID == nil {
                // The empty state is not a message list. Keep it in the
                // normal AppKit/SwiftUI resize path instead of snapshotting
                // and freezing it during a split resize.
                NoConversationSelectedView()
            } else {
                LiveResizeFrozenView {
                    routedMessageList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.surface)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 选中切换：更新空态/列表路由，并同步新会话的 verbosity。
        .onReceive(NotificationCenter.default.publisher(for: LumiListNotifications.selectedConversationDidChange)) { notification in
            let newID = notification.lumiConversationID
            selectedConversationID = newID
            verbosity = services.verbosity(for: newID)
        }
        // 会话设置变化（setVerbosity 等广播 conversationsDidChange）：刷新路由用 verbosity。
        .onReceive(NotificationCenter.default.publisher(for: LumiListNotifications.conversationsDidChange)) { _ in
            let newVerbosity = services.verbosity(for: services.selectedConversationID)
            verbosity = newVerbosity
        }
    }

    /// 根据 verbosity 路由到对应的消息列表子视图。
    @ViewBuilder
    private var routedMessageList: some View {
        switch verbosity {
        case .brief:
            ListV1View(services: services)
        case .standard:
            ListV2View(services: services)
        case .detailed:
            ListV3View(services: services)
        }
    }
}
