import LumiKernel
import LumiUI
import SwiftUI

struct ActivityBar: View {
    @Environment(\.openWindow) private var openWindow
    var workspace: any WorkspaceProviding

    private var containers: [ViewContainerItem] {
        workspace.allViewContainers
    }

    private var activeID: String? {
        workspace.activeViewContainerID
    }

    var body: some View {
        VStack(spacing: 6) {
            ForEach(containers) { container in
                AppActivityIconButton(
                    systemImage: container.systemImage,
                    label: container.title,
                    isActive: activeID == container.id
                ) {
                    workspace.activateContainer(id: container.id)
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
