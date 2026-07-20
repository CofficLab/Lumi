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
        // 不要设 idealWidth。HSplitView 看到 idealWidth 后会按它算 divider 位置（narrow=320, wide=480），
        // 后续 layout pass 会反向覆盖 SplitDividerPersistenceView 写进去的位置——导致切 view container
        // 切回来时 chat section 宽度被强制回弹到 idealWidth，丢掉了用户拖出来的窄值。
        // divider 位置由 SplitDividerPersistenceView 完全决定，这里只保留下界（minWidth 防缩成 0）
        // 和上界（maxWidth = .infinity 不限制）。
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