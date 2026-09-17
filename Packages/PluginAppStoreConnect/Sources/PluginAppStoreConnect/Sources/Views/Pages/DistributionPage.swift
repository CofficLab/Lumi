import LumiUI
import SwiftUI

struct DistributionPage: View {
    @ObservedObject var viewModel: VM
    @Binding var importingScreenshots: Bool

    var body: some View {
        Group {
            if viewModel.selectedApp == nil {
                AppEmptyState(
                    icon: "square.grid.2x2",
                    title: AppStoreConnectLocalization.string("No App Selected"),
                    description: AppStoreConnectLocalization.string("Select an app from the sidebar.")
                )
            } else {
                // 选中 APP 后，显示版本选择器和详情
                versionContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if viewModel.selectedApp != nil && viewModel.versions.isEmpty {
                await viewModel.loadVersions()
            }
        }
    }

    // MARK: - Version Content

    @ViewBuilder
    private var versionContent: some View {
        VStack(spacing: 0) {
            // 顶部只保留版本选择、语言与操作
            versionToolbar

            Divider()

            if let version = viewModel.selectedVersion {
                VersionOverviewView(version: version)
            }

            // 版本详情
            if viewModel.selectedVersion == nil {
                AppEmptyState(
                    icon: "number",
                    title: AppStoreConnectLocalization.string("No Version Selected"),
                    description: AppStoreConnectLocalization.string("Choose a version from the selector above.")
                )
            } else if viewModel.isReadOnlyVersion, let version = viewModel.selectedVersion {
                ReadOnlyPage(viewModel: viewModel, version: version)
            } else if let version = viewModel.selectedVersion {
                EditablePage(
                    viewModel: viewModel,
                    version: version,
                    importingScreenshots: $importingScreenshots
                )
            }
        }
        .onChange(of: viewModel.selectedScreenshotDisplayType) { _, _ in
            Task { await viewModel.reloadScreenshotsForSelectedDisplayType() }
        }
    }

    // MARK: - Version Picker

    private var versionToolbar: some View {
        AppToolbarContainer(padding: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) {
            HStack(spacing: 16) {
                versionPicker

                if let version = viewModel.selectedVersion {
                    VersionActionsBar(
                        version: version,
                        viewModel: viewModel,
                        localePickerSourceView: "DistributionPage.localePicker",
                        embedded: true
                    )
                }
            }
        }
    }

    private var versionPicker: some View {
        ToolbarSelectControl(
            title: versionSelectionTitle,
            systemImage: "shippingbox",
            maxTitleWidth: 220
        ) {
            VersionOptionsView(viewModel: viewModel, groups: groupedVersions)
        }
    }

    private var versionSelectionTitle: String {
        guard let version = viewModel.selectedVersion else {
            return AppStoreConnectLocalization.string("Select a version")
        }
        return versionDisplayTitle(version)
    }

    // MARK: - Helpers

    private var groupedVersions: [(platform: String, versions: [AppStoreVersion])] {
        let grouped = Dictionary(grouping: viewModel.versions, by: { $0.platform.normalizedASCPlatform })
        return grouped
            .map { (platform: $0.key, versions: $0.value.sorted { $0.versionString > $1.versionString }) }
            .sorted { lhs, rhs in
                platformSortIndex(lhs.platform) < platformSortIndex(rhs.platform)
            }
    }

    private func versionDisplayTitle(_ version: AppStoreVersion) -> String {
        let platform = version.platform.normalizedASCPlatform
        let platformDisplay = platformDisplayName(platform)
        return "\(version.versionString) (\(platformDisplay))"
    }

    private func platformDisplayName(_ platform: String) -> String {
        switch platform.normalizedASCPlatform {
        case "MAC_OS":
            return AppStoreConnectLocalization.string("macOS")
        case "IOS":
            return AppStoreConnectLocalization.string("iOS")
        case "TV_OS":
            return AppStoreConnectLocalization.string("tvOS")
        case "VISION_OS":
            return AppStoreConnectLocalization.string("visionOS")
        default:
            return platform
        }
    }

    private func platformSortIndex(_ platform: String) -> Int {
        let platformOrder = ["IOS", "MAC_OS", "TV_OS", "VISION_OS"]
        return platformOrder.firstIndex(of: platform.normalizedASCPlatform) ?? Int.max
    }
}

private struct VersionOptionsView: View {
    @ObservedObject var viewModel: VM
    let groups: [(platform: String, versions: [AppStoreVersion])]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(AppStoreConnectLocalization.string("Version"))
                .font(.headline)

            if groups.isEmpty {
                Text(AppStoreConnectLocalization.string("No Versions"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(groups, id: \.platform) { group in
                            Text(platformDisplayName(group.platform))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 8)

                            ForEach(group.versions, id: \.id) { version in
                                Button {
                                    viewModel.selectVersion(version)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text(version.versionString)
                                            .font(.system(size: 13, weight: .medium))
                                        Spacer()
                                        if viewModel.selectedVersion?.id == version.id {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.tint)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 7)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        viewModel.selectedVersion?.id == version.id
                                            ? Color.accentColor.opacity(0.12)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 280)
    }

    private func platformDisplayName(_ platform: String) -> String {
        switch platform.normalizedASCPlatform {
        case "MAC_OS":
            return AppStoreConnectLocalization.string("macOS")
        case "IOS":
            return AppStoreConnectLocalization.string("iOS")
        case "TV_OS":
            return AppStoreConnectLocalization.string("tvOS")
        case "VISION_OS":
            return AppStoreConnectLocalization.string("visionOS")
        default:
            return platform
        }
    }
}
