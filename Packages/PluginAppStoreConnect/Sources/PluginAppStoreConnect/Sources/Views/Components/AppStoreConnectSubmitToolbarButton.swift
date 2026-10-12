import LumiUI
import SwiftUI

/// 主工具栏右侧的版本操作按钮，根据版本状态显示对应动作。
///
/// 三个状态互斥，同一时刻只显示其中一个：
/// - 可提交审核 → 提交审核
/// - 审核中 → 撤回提交
/// - 审核通过待发布 → 发布到 App Store
struct AppStoreConnectSubmitToolbarButton: View {
    @ObservedObject var viewModel: VM
    @State private var showsSubmitConfirmation = false
    @State private var showsWithdrawConfirmation = false
    @State private var showsReleaseConfirmation = false

    var body: some View {
        if let version = viewModel.selectedVersion {
            button(version: version)
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
                .confirmationDialog(
                    AppStoreConnectLocalization.string("Withdraw Submission"),
                    isPresented: $showsWithdrawConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(AppStoreConnectLocalization.string("Withdraw"), role: .destructive) {
                        Task { await viewModel.withdrawSubmission() }
                    }
                    Button(AppStoreConnectLocalization.string("Cancel"), role: .cancel) {}
                } message: {
                    Text(AppStoreConnectLocalization.string(
                        "Withdraw the submission for version %@? The build will return to the prepare state.",
                        version.versionString
                    ))
                }
                .confirmationDialog(
                    AppStoreConnectLocalization.string("Release Version"),
                    isPresented: $showsReleaseConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(AppStoreConnectLocalization.string("Release"), role: .destructive) {
                        Task { await viewModel.releaseVersion(version) }
                    }
                    Button(AppStoreConnectLocalization.string("Cancel"), role: .cancel) {}
                } message: {
                    Text(AppStoreConnectLocalization.string(
                        "Release %@ to the App Store? This action cannot be undone via the API.",
                        version.versionString
                    ))
                }
        }
    }

    @ViewBuilder
    private func button(version: AppStoreVersion) -> some View {
        if version.isSubmittable {
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
        } else if viewModel.submissionID != nil {
            AppButton(
                AppStoreConnectLocalization.string("Withdraw Submission"),
                systemImage: "arrow.uturn.backward.circle",
                style: .secondary,
                size: .small
            ) {
                showsWithdrawConfirmation = true
            }
            .disabled(viewModel.isBusy)
        } else if version.isPendingDeveloperRelease {
            AppButton(
                AppStoreConnectLocalization.string("Release to App Store"),
                systemImage: "arrow.up.circle.fill",
                style: .primary,
                size: .small
            ) {
                showsReleaseConfirmation = true
            }
            .disabled(viewModel.isBusy)
        }
    }
}
