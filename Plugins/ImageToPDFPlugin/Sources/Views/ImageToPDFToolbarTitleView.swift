import LumiKernel
import SwiftUI

/// Toolbar title view that only displays when this plugin's container is active.
struct ImageToPDFToolbarTitleView: View {
    let containerID: String
    let kernel: LumiKernel

    // 在 init 阶段同步绑定：本视图是条件 body，异步 .task 绑定会导致时序竞争。
    @StateObject private var workspaceBox: ObservableWorkspaceBox

    init(containerID: String, kernel: LumiKernel) {
        self.containerID = containerID
        self.kernel = kernel
        _workspaceBox = StateObject(wrappedValue: ObservableWorkspaceBox(service: kernel.workspace))
    }

    var body: some View {
        Group {
            if workspaceBox.service?.activeViewContainerID == containerID {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(ImageToPDFLocalization.string("Image to PDF"))
                        .font(.headline)
                }
            }
        }
    }
}
