import LumiUI
import SwiftUI

struct VersionsSection: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(platformTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !viewModel.sidebarVersions.isEmpty {
                    Text("\(viewModel.sidebarVersions.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Button {
                    Task { await viewModel.loadVersions() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .disabled(viewModel.isBusy)
                .help(AppStoreConnectLocalization.string("Refresh"))
            }
            .padding(.horizontal, 12)
            .padding(.top, 0)

            if viewModel.sidebarVersions.isEmpty {
                Text(AppStoreConnectLocalization.string("No versions loaded"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(groupedSidebarVersions, id: \.platform) { group in
                            Text(platformDisplayName(group.platform))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.top, 10)
                                .padding(.bottom, 4)

                            ForEach(group.versions, id: \.id) { version in
                                SidebarVersionRow(
                                    version: version,
                                    isSelected: isVersionSelected(version)
                                ) {
                                    viewModel.openDistribution(for: version)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .task {
            if viewModel.sidebarVersions.isEmpty, viewModel.selectedApp != nil {
                await viewModel.loadVersions()
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Private

    private let platformOrder: [String] = ["IOS", "MAC_OS", "TV_OS", "VISION_OS"]

    private var platformTitle: String {
        AppStoreConnectLocalization.string("App Versions")
    }

    private var groupedSidebarVersions: [(platform: String, versions: [AppStoreVersion])] {
        let grouped = Dictionary(grouping: viewModel.sidebarVersions, by: { $0.platform.normalizedASCPlatform })
        return grouped
            .map { (platform: $0.key, versions: $0.value) }
            .sorted { lhs, rhs in
                platformSortIndex(lhs.platform) < platformSortIndex(rhs.platform)
            }
    }

    private func platformSortIndex(_ platform: String) -> Int {
        let normalized = platform.normalizedASCPlatform
        return platformOrder.firstIndex(of: normalized) ?? Int.max
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

    private func isVersionSelected(_ version: AppStoreVersion) -> Bool {
        guard viewModel.page == .distribution,
              let selected = viewModel.selectedVersion else { return false }
        return version.id == selected.id
    }
}
