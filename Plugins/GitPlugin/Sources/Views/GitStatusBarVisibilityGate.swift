import LumiKernel
import SwiftUI

/// Keeps Git-specific status bar content scoped to the Git view container.
struct GitStatusBarVisibilityGate<Content: View>: View {
    let containerID: String
    let kernel: LumiKernel
    @ViewBuilder let content: () -> Content

    @State private var activeContainerID: String?

    init(
        containerID: String,
        kernel: LumiKernel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.containerID = containerID
        self.kernel = kernel
        self.content = content
        _activeContainerID = State(initialValue: kernel.workspace?.activeViewContainerID)
    }

    var body: some View {
        Group {
            if Self.isVisible(activeContainerID: activeContainerID, containerID: containerID) {
                content()
            }
        }
        .onActiveViewContainerIDDidChange { newContainerID in
            activeContainerID = newContainerID
        }
    }

    static func isVisible(activeContainerID: String?, containerID: String) -> Bool {
        activeContainerID == containerID
    }
}
