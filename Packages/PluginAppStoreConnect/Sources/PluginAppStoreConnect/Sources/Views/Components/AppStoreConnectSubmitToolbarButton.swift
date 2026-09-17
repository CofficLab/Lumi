import LumiUI
import SwiftUI

/// 主工具栏右侧的「提交审核」按钮，位于版本/语言选择器左侧。
struct AppStoreConnectSubmitToolbarButton: View {
    @ObservedObject var viewModel: VM
    @State private var showsSubmitConfirmation = false

    var body: some View {
        if let version = viewModel.selectedVersion, version.isSubmittable {
            AppButton(
                AppStoreConnectLocalization.string("Submit for Review"),
                systemImage: "paperplane.fill",
                style: .primary,
                size: .small
            ) {
                showsSubmitConfirmation = true
            }
            .disabled(viewModel.isBusy || viewModel.assignedBuildID == nil)
            .help(viewModel.assignedBuildID == nil
                ? AppStoreConnectLocalization.string("Assign a build before submitting for review.")
                : AppStoreConnectLocalization.string("Submit this version to App Review."))
            .confirmationDialog(
                AppStoreConnectLocalization.string("Submit for Review"),
                isPresented: $showsSubmitConfirmation,
                titleVisibility: .visible
            ) {
                Button(AppStoreConnectLocalization.string("Submit"), role: .destructive) {
                    Task { await viewModel.submitForReview() }
                }
                Button(AppStoreConnectLocalization.string("Cancel"), role: .cancel) {}
            } message: {
                Text(AppStoreConnectLocalization.string(
                    "Submit version %@ to App Review? Make sure the build, metadata, and screenshots are complete.",
                    version.versionString
                ))
            }
        }
    }
}
