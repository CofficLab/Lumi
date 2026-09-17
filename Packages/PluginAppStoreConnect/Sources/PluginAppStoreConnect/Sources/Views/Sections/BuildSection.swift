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
        .padding(.top, 12)
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack {
            Text(AppStoreConnectLocalization.string("Build"))
                .font(.title3.weight(.semibold))

            Spacer()
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
                pickerRow

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

    // MARK: - Pickers

    /// Build 与出口合规选择同处一行，控件自带图标与当前值，不再重复左侧文字标签。
    /// 宽度不足时（窄窗口 / iPhone）自动回退为两行，避免文案被过度压缩。
    private var pickerRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                buildPicker
                if let selected = selectedBuild {
                    exportCompliancePicker(selected)
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 12) {
                buildPicker
                if let selected = selectedBuild {
                    exportCompliancePicker(selected)
                }
            }
        }
    }

    private var buildPicker: some View {
        ToolbarSelectControl(
            title: selectedBuild.map(BuildDisplay.label)
                ?? AppStoreConnectLocalization.string("Select a build"),
            systemImage: "shippingbox",
            iconTint: isSelectedBuildAssigned ? .accentColor : nil,
            maxTitleWidth: 280
        ) {
            BuildOptionsView(viewModel: viewModel)
        }
        .disabled(!version.canAssignBuild)
        .help(AppStoreConnectLocalization.string("Build"))
    }

    /// 出口合规选择：与 Build / 版本 / 语言选择保持一致的弹层选择控件。
    @ViewBuilder
    private func exportCompliancePicker(_ build: ConnectBuild) -> some View {
        let choice = ExportComplianceChoice.choice(for: build.usesNonExemptEncryption)
        ToolbarSelectControl(
            title: choice?.title ?? AppStoreConnectLocalization.string("Not declared"),
            systemImage: choice?.systemImage ?? "exclamationmark.triangle",
            maxTitleWidth: 220
        ) {
            ExportComplianceOptionsView(
                viewModel: viewModel,
                currentValue: build.usesNonExemptEncryption
            )
        }
        .disabled(!version.canAssignBuild)
        .help(AppStoreConnectLocalization.string("Export Compliance"))
    }

    private func buildDetail(_ build: ConnectBuild) -> some View {
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

    /// 当前选中的 build 是否就是已关联到该版本的 build
    private var isSelectedBuildAssigned: Bool {
        guard let selected = selectedBuild else { return false }
        return viewModel.assignedBuildID == selected.id
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

private struct BuildOptionsView: View {
    @ObservedObject var viewModel: VM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStoreConnectLocalization.string("Build"))
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.builds) { build in
                        Button {
                            viewModel.selectedBuildID = build.id
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: BuildDisplay.icon(for: build))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(BuildDisplay.iconColor(
                                        for: build,
                                        isAssigned: viewModel.assignedBuildID == build.id
                                    ))
                                    .frame(width: 20)

                                Text(BuildDisplay.label(for: build))
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Spacer()

                                if viewModel.selectedBuildID == build.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                viewModel.selectedBuildID == build.id
                                    ? Color.accentColor.opacity(0.12)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 280)
        }
        .frame(width: 320)
    }
}
