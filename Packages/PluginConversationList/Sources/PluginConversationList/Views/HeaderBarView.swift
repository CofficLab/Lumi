import SwiftUI

/// 对话列表顶部标题栏：根据 scope 与当前项目动态显示。
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
                HStack(spacing: 6) {
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.06))
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
