import LumiKernel
import LumiUI
import SwiftUI

struct PanelBodyView: View {
    @LumiTheme private var theme

    let container: ViewContainerItem?

    var body: some View {
        Group {
            if let container, let makeView = container.makeView {
                makeView()
                    .id(container.id)
            } else {
                ZStack {
                    theme.surface
                    AppEmptyState(
                        icon: "rectangle.center.inset.filled",
                        title: "No content"
                    )
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
