import LumiUI
import SwiftUI

/// 对话列表顶部标题栏：根据 scope 与当前项目动态显示。
///
/// 视觉规格来自 LumiUI 的 `AppPanelBar`——与聊天工具栏（`ChatToolbarRow`）
/// 共用同一份「面板栏」定义，因此高度、内边距、背景与底部边框保持一致。
///
/// 右侧的对话条数徽标可点击，点击后弹出「对话统计」面板
/// （每日对话数量折线图 + 按时间批量清理历史对话）。
///
/// View 只依赖 `ConversationListViewModel`，不创建外部 Observer。
struct HeaderBarView: View {
    @ObservedObject private var viewModel: ConversationListViewModel

    /// 统计面板是否已弹出。
    @State private var isStatsPopoverPresented = false

    init(viewModel: ConversationListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Group {
            if viewModel.headerVisible {
                AppPanelBar {
                    HStack(spacing: AppPanelChromeMetrics.breadcrumbItemSpacing) {
                        Image(systemName: headerIcon)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(viewModel.headerTitle)
                            .font(.appCaption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                        // 右侧展示当前作用域的对话条数；点击查看统计。
                        ConversationCountBadge(count: viewModel.conversationCount) {
                            isStatsPopoverPresented = true
                        }
                    }
                }
                .popover(isPresented: $isStatsPopoverPresented, arrowEdge: .bottom) {
                    ConversationStatsPopover(
                        capability: viewModel.statsCapability,
                        projectPath: viewModel.statsProjectPath
                    )
                }
            }
        }
    }

    private var headerIcon: String {
        switch viewModel.scope {
        case .currentProject:
            return "folder.fill"
        case .all:
            return "tray.full.fill"
        }
    }
}
