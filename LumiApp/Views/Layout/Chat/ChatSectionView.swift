import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatSectionView: View {
    let layout: LumiChatSectionLayout
    let toolbarBarItems: [LumiChatSectionToolbarBarItem]
    let headerItems: [LumiChatSectionHeaderItem]
    let stackItems: [LumiChatSectionItem]
    let bottomItems: [LumiChatSectionItem]
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
            minWidth: layout.minWidth,
            idealWidth: layout.idealWidth,
            maxWidth: layout.maximumWidth
        )
    }

    static func makeRootContent(
        stackItems: [LumiChatSectionItem],
        bottomItems: [LumiChatSectionItem]
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
