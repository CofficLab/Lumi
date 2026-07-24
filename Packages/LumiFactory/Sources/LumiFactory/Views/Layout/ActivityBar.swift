import LumiKernel
import LumiUI
import SwiftUI

struct ActivityBar: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var kernel: LumiKernel

    private var containers: [ViewContainerItem] {
        kernel.viewContainer?.allViewContainers ?? []
    }

    private var activeID: String? {
        kernel.layout?.layoutState.activeViewContainerID
            ?? kernel.layout?.state.activeSectionID
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(containers) { container in
                AppActivityIconButton(
                    systemImage: container.systemImage,
                    label: container.title,
                    isActive: activeID == container.id
                ) {
                    // 激活容器
                    kernel.layout?.layoutState.activateContainer(id: container.id)
                    kernel.layout?.updateLayout { state in
                        state.activeSectionID = container.id
                        state.activeSectionTitle = container.title
                    }
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
        .borderTrailing()
    }
}
