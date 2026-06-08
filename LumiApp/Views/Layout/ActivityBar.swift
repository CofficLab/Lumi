import LumiCoreKit
import LumiUI
import SwiftUI

struct ActivityBar: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var state: LayoutState
    let containers: [LumiViewContainerItem]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(containers) { container in
                AppActivityIconButton(
                    systemImage: container.systemImage,
                    label: container.title,
                    isActive: state.activeViewContainerID == container.id
                ) {
                    state.activateViewContainer(id: container.id)
                }
            }

            Spacer()

            AppIconButton(
                systemImage: "gearshape",
                size: .regular
            ) {
                openWindow(id: AppBootstrap.settingsWindowID)
            }
            .help("Settings")
        }
        .padding(.vertical, 8)
        .frame(width: 48)
        .appSurface(style: .panel, cornerRadius: 0)
    }
}
