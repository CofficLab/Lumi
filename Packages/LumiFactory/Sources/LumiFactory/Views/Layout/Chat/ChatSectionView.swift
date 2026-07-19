import LumiKernel
import LumiUI
import SwiftUI

struct ChatSectionView: View {
    let minWidth: CGFloat
    let maxWidth: CGFloat?
    let toolbarBarItems: [ChatSectionToolbarBarItem]
    let headerItems: [ChatSectionHeaderItem]
    let stackItems: [ChatSectionItem]
    let bottomItems: [ChatSectionItem]
    let rootContent: AnyView

    var body: some View {
        VStack(spacing: 0) {
            ChatHeaderView(items: headerItems)
            ChatToolbarView(items: toolbarBarItems)

            rootContent
                .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .frame(
            minWidth: minWidth,
            maxWidth: maxWidth ?? .infinity
        )
    }

    static func makeRootContent(
        stackItems: [ChatSectionItem],
        bottomItems: [ChatSectionItem]
    ) -> AnyView {
        AnyView(
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
        )
    }
}