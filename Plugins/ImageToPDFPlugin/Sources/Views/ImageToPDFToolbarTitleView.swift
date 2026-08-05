import LumiKernel
import SwiftUI

/// Toolbar title view that only displays when this plugin's container is active.
struct ImageToPDFToolbarTitleView: View {
    let containerID: String
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        if kernel.workspace?.activeViewContainerID == containerID {
            HStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                Text(ImageToPDFLocalization.string("Image to PDF"))
                    .font(.headline)
            }
        }
    }
}
