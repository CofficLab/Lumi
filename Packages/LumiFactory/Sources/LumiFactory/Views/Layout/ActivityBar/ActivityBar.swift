import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

struct ActivityBar: View, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "ui.activity-bar")
    nonisolated static let emoji = "📍"
    nonisolated static let verbose = true

    @LumiTheme private var theme
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var kernel: LumiKernel
    @State private var highlightedContainerID: String?

    var body: some View {
        VStack(spacing: 6) {
            if let workspace = kernel.workspace {
                containerList(workspace: workspace)
            } else {
                ActivityBarErrorView()
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
        #if DEBUG
        .overlay(
            Rectangle()
                .fill(theme.warning.opacity(0.20))
                .allowsHitTesting(false)
        )
        #endif
    }

    // MARK: - Container List

    @ViewBuilder
    private func containerList(workspace: any WorkspaceProviding) -> some View {
        ForEach(workspace.allViewContainers) { container in
            AppActivityIconButton(
                systemImage: container.systemImage,
                label: container.title,
                isActive: highlightedContainerID == container.id
            ) {
                highlightedContainerID = container.id
                workspace.activateContainer(id: container.id)
            }
        }
        .onAppear {
            highlightedContainerID = workspace.activeViewContainerID
        }
        .onActiveViewContainerIDDidChange { activeID in
            highlightedContainerID = activeID
        }
    }
}
