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
            // 版本选择器
            versionPicker
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

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

    private var versionPicker: some View {
        HStack(spacing: 12) {
            Text(AppStoreConnectLocalization.string("Version"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: $viewModel.selectedVersion) {
                Text(AppStoreConnectLocalization.string("Select a version"))
                    .tag(nil as AppStoreVersion?)

                if !viewModel.versions.isEmpty {
                    ForEach(groupedVersions, id: \.platform) { group in
                        ForEach(group.versions, id: \.id) { version in
                            versionLabel(version, platform: group.platform)
                                .tag(version as AppStoreVersion?)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 300)

            Spacer()

            // 刷新按钮
            AppIconButton(systemImage: "arrow.clockwise") {
                Task { await viewModel.loadVersions() }
            }
            .disabled(viewModel.isBusy)
            .help(AppStoreConnectLocalization.string("Refresh"))
        }
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

    private func versionLabel(_ version: AppStoreVersion, platform: String) -> Text {
        let platformDisplay = platformDisplayName(platform)
        return Text("\(version.versionString) (\(platformDisplay))")
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
