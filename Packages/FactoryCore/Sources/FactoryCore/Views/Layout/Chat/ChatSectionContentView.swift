import KernelLumi
import LumiUI
import SwiftUI

/// 只负责渲染插件注册的 ChatSection 内容区（stack + bottomFixed）
///
/// 不订阅 workspace 服务的 `objectWillChange`，
/// 改为「快照 + 事件刷新」：init 读一次初值，监听 `.workspaceContributionsDidChange`
/// 重新拉取 chatSectionItems。
struct ChatSectionContentView: View {
    let kernel: KernelLumi

    @State private var allItems: [ChatSectionItem] = []

    private var stackItems: [ChatSectionItem] {
        allItems.filter { $0.placement == .stack }
    }

    private var bottomItems: [ChatSectionItem] {
        allItems.filter { $0.placement == .bottomFixed }
    }

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _allItems = State(initialValue: kernel.workspace?.allChatSectionItems ?? [])
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
        .onWorkspaceContributionsDidChange {
            allItems = kernel.workspace?.allChatSectionItems ?? []
        }
    }
}
