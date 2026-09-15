import LumiUI
import SwiftUI

/// 对话列表顶部标题栏：根据 scope 与当前项目动态显示。
///
/// 视觉规格来自 LumiUI 的 `AppPanelBar`——与聊天工具栏（`ChatToolbarRow`）
/// 共用同一份「面板栏」定义，因此高度、内边距、背景与底部边框保持一致。
///
/// View 只依赖 `ConversationListViewModel`，不创建外部 Observer。
struct HeaderBarView: View {
    @ObservedObject private var viewModel: ConversationListViewModel

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
                    }
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
