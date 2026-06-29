import LumiCoreKit
import LumiUI
import SwiftUI

struct PanelHeaderView: View {
    @LumiTheme private var theme
    
    let items: [LumiPanelHeaderItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                item.makeView()
                    .id(item.id)
                    .zIndex(Double(items.count - index)) // 上面的 item 有更高的 zIndex，shadow 能显示在下面的 item 上
            }
        }
    }
}
