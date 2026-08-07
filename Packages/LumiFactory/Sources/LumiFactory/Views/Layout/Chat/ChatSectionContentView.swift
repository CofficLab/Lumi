import LumiKernel
import LumiUI
import SwiftUI

/// 只负责渲染插件注册的 ChatSection 内容区（stack + bottomFixed）
struct ChatSectionContentView: View {
    let kernel: LumiKernel

    // 只订阅 workspace 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/conversations/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var workspaceBox = ObservableWorkspaceBox()

    private var stackItems: [ChatSectionItem] {
        workspaceBox.service?.allChatSectionItems.filter { $0.placement == .stack } ?? []
    }

    private var bottomItems: [ChatSectionItem] {
        workspaceBox.service?.allChatSectionItems.filter { $0.placement == .bottomFixed } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            let hasExplicitPrimaryStack = stackItems.contains(where: \.fillsRemainingHeight)

            ForEach(Array(stackItems.enumerated()), id: \.element.id) { index, item in
                let isPrimaryStack = item.fillsRemainingHeight
                    || (!hasExplicitPrimaryStack && index == 0)

                item.makeView()
                    .frame(maxWidth: .infinity, alignment: .top)
                    .frame(maxHeight: isPrimaryStack ? .infinity : nil, alignment: .top)
                    .layoutPriority(isPrimaryStack ? 1 : 0)

                if index < stackItems.count - 1, item.showsTrailingDivider {
                    AppDivider()
                }
            }

            if !stackItems.isEmpty, !bottomItems.isEmpty,
               stackItems.last?.showsTrailingDivider ?? true {
                AppDivider()
            }

            ForEach(Array(bottomItems.enumerated()), id: \.element.id) { index, item in
                item.makeView()
                    .frame(maxWidth: .infinity, alignment: .bottom)

                if index < bottomItems.count - 1, item.showsTrailingDivider {
                    AppDivider()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .task { workspaceBox.bind(kernel.workspace) }
    }
}
