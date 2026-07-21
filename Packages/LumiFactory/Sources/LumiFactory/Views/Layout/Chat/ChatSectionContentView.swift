import LumiKernel
import LumiUI
import SwiftUI

/// 只负责渲染插件注册的 ChatSection 内容区（stack + bottomFixed）
struct ChatSectionContentView: View {
    @ObservedObject var kernel: LumiKernel

    private var stackItems: [ChatSectionItem] {
        kernel.chatSection?.allChatSectionItems.filter { $0.placement == .stack } ?? []
    }

    private var bottomItems: [ChatSectionItem] {
        kernel.chatSection?.allChatSectionItems.filter { $0.placement == .bottomFixed } ?? []
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

                if index < bottomItems.count - 1 {
                    AppDivider()
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
