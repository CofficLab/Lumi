import LumiKernel
import LumiUI
import SwiftUI

struct PanelHeaderView: View {
    @LumiTheme private var theme
    
    let items: [PanelHeaderItem]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                item.makeView()
                    .id(item.id)
            }
        }
    }
}
