import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatSectionView: View {
    let layout: LumiChatSectionLayout
    let stackItems: [LumiChatSectionItem]
    let bottomItems: [LumiChatSectionItem]
    let rootContent: AnyView

    var body: some View {
        rootContent
            .frame(maxHeight: .infinity)
            .frame(
                minWidth: layout.minWidth,
                idealWidth: layout.idealWidth,
                maxWidth: layout.maximumWidth
            )
            .appSurface(style: .panel, cornerRadius: 0)
    }

    static func makeRootContent(
        stackItems: [LumiChatSectionItem],
        bottomItems: [LumiChatSectionItem]
    ) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                ForEach(Array(stackItems.enumerated()), id: \.element.id) { index, item in
                    let isPrimaryStack = index == 0

                    item.makeView()
                        .frame(maxWidth: .infinity, alignment: .top)
                        .frame(maxHeight: isPrimaryStack ? .infinity : nil, alignment: .top)
                        .layoutPriority(isPrimaryStack ? 1 : 0)

                    if index < stackItems.count - 1 {
                        GlassDivider()
                    }
                }

                if !stackItems.isEmpty, !bottomItems.isEmpty {
                    GlassDivider()
                }

                ForEach(Array(bottomItems.enumerated()), id: \.element.id) { index, item in
                    item.makeView()
                        .frame(maxWidth: .infinity, alignment: .bottom)

                    if index < bottomItems.count - 1 {
                        GlassDivider()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        )
    }
}
