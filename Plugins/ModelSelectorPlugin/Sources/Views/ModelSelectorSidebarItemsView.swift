import LumiKernel
import SwiftUI

struct ModelSelectorSidebarItemsView: View {
    let items: [ModelSelectorSidebarItem]

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: 8) {
                ForEach(items.sorted { lhs, rhs in
                    if lhs.order == rhs.order { return lhs.id < rhs.id }
                    return lhs.order < rhs.order
                }) { item in
                    item.makeView()
                }
            }
            .padding(8)
        }
    }
}
