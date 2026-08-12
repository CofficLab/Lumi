import LumiUI
import SwiftUI

/// Build 选择区块：列出可选构建、关联到版本、声明加密合规。
/// 这是提交审核前的必需步骤。
struct BuildSection: View {
    @ObservedObject var viewModel: VM
    let version: AppStoreVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            content
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text(AppStoreConnectLocalization.string("Build"))
                .font(.title3.weight(.semibold))

            Spacer()

            AppIconButton(systemImage: "arrow.clockwise") {
                Task { await viewModel.loadReleaseInfo(forceRefresh: true) }
            }
            .disabled(viewModel.isBusy)
            .help(AppStoreConnectLocalization.string("Refresh"))
        }
        .padding(.horizontal)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.builds.isEmpty, !viewModel.isBusy {
            AppEmptyState(
                icon: "hammer",
                title: AppStoreConnectLocalization.string("No Builds Available"),
                description: AppStoreConnectLocalization.string("Upload a build with Xcode or Transporter first, then refresh. Builds still processing on Apple servers cannot be selected yet.")
            )
            .frame(minHeight: 120)
            .padding(.horizontal)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                buildPicker

                if let selected = selectedBuild {
                    buildDetail(selected)
                }

                if version.canAssignBuild {
                    assignButton
                }
            }
            .padding(.horizontal)
        }
    }

    private var buildPicker: some View {
        HStack(spacing: 12) {
            Text(AppStoreConnectLocalization.string("Build"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: $viewModel.selectedBuildID) {
                Text(AppStoreConnectLocalization.string("Select a build"))
                    .tag(nil as String?)
                ForEach(viewModel.builds) { build in
                    Text(buildOptionLabel(build))
                        .tag(build.id as String?)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 360)
            .disabled(!version.canAssignBuild)
        }
    }

    @ViewBuilder
    private func buildDetail(_ build: ConnectBuild) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                if let uploaded = build.uploadedDate {
                    Label(ViewFormatting.formatDateTime(uploaded), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let minOS = build.minOsVersion {
                    Label(AppStoreConnectLocalization.string("minOS %@", minOS), systemImage: "gear")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                processingStateLabel(build)
            }

            // 加密合规声明
            HStack(spacing: 8) {
                Text(AppStoreConnectLocalization.string("Export Compliance"))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let usesNonExempt = build.usesNonExemptEncryption {
                    Text(usesNonExempt
                        ? AppStoreConnectLocalization.string("Uses non-exempt encryption")
                        : AppStoreConnectLocalization.string("No non-exempt encryption"))
                        .font(.caption)
                } else {
                    Text(AppStoreConnectLocalization.string("Not declared"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if version.canAssignBuild {
                    Menu(AppStoreConnectLocalization.string("Change")) {
                        Button(AppStoreConnectLocalization.string("No non-exempt encryption")) {
                            Task { await viewModel.updateSelectedBuildEncryption(usesNonExemptEncryption: false) }
                        }
                        Button(AppStoreConnectLocalization.string("Uses non-exempt encryption")) {
                            Task { await viewModel.updateSelectedBuildEncryption(usesNonExemptEncryption: true) }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .font(.caption)
                    .fixedSize()
                }
            }
        }
    }

    private var assignButton: some View {
        HStack(spacing: 12) {
            AppButton(
                AppStoreConnectLocalization.string("Assign Build to Version"),
                systemImage: "link",
                style: .primary,
                size: .small
            ) {
                Task { await viewModel.assignSelectedBuild() }
            }
            .disabled(viewModel.isBusy || !canAssign)

            if let assignedID = viewModel.assignedBuildID,
               let assigned = viewModel.builds.first(where: { $0.id == assignedID }) {
                Label(
                    AppStoreConnectLocalization.string("Assigned: %@", assigned.displayLabel),
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Helpers

    private var selectedBuild: ConnectBuild? {
        guard let id = viewModel.selectedBuildID else { return nil }
        return viewModel.builds.first { $0.id == id }
    }

    private var canAssign: Bool {
        guard let selected = selectedBuild else { return false }
        return selected.isAssignable && viewModel.assignedBuildID != selected.id
    }

    private func buildOptionLabel(_ build: ConnectBuild) -> String {
        var label = build.displayLabel
        if build.isProcessing {
            label += AppStoreConnectLocalization.string(" (processing…)")
        } else if !build.isAssignable {
            label += AppStoreConnectLocalization.string(" (invalid)")
        } else if viewModel.assignedBuildID == build.id {
            label += AppStoreConnectLocalization.string(" (assigned)")
        }
        return label
    }

    @ViewBuilder
    private func processingStateLabel(_ build: ConnectBuild) -> some View {
        switch build.processingState.uppercased() {
        case "VALID":
            Label(AppStoreConnectLocalization.string("Valid"), systemImage: "checkmark.seal")
                .font(.caption)
                .foregroundStyle(.green)
        case "PROCESSING":
            Label(AppStoreConnectLocalization.string("Processing"), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.orange)
        default:
            Label(build.processingState, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}
