import LumiKernel
import LumiUI
import SwiftUI

struct ContentWorkspaceView: View {
    @LumiTheme private var theme
    let container: LumiViewContainerItem?

    var body: some View {
        ZStack {
            if let container {
                container.makeView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                theme.surface

                AppEmptyState(
                    icon: "rectangle.center.inset.filled",
                    title: "No content"
                )
                .padding(24)
            }
        }
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        .appSurface(style: .panel, cornerRadius: 0)
    }
}
