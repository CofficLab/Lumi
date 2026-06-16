import LumiUI
import SwiftUI

struct VersionsSection: View {
    @ObservedObject var viewModel: ConnectViewModel

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
                        ForEach(viewModel.sidebarVersions) { version in
                            SidebarVersionRow(
                                version: version,
                                isSelected: isVersionSelected(version)
                            ) {
                                viewModel.openDistribution(for: version)
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Private

    private var platformTitle: String {
        guard let app = viewModel.selectedApp else {
            return AppStoreConnectLocalization.string("App Versions")
        }
        // If versions exist, derive platform label from the first version's platform.
        // This handles cases where an iOS app has Mac Catalyst versions (API returns
        // platform=IOS for the app but MAC_OS for each version).
        let effectivePlatform: String
        if let firstVersion = viewModel.sidebarVersions.first {
            effectivePlatform = firstVersion.platform.normalizedASCPlatform
        } else {
            effectivePlatform = app.platform.normalizedASCPlatform
        }
        switch effectivePlatform {
        case "MAC_OS": return AppStoreConnectLocalization.string("macOS App")
        case "IOS": return AppStoreConnectLocalization.string("iOS App")
        case "TV_OS": return AppStoreConnectLocalization.string("tvOS App")
        case "VISION_OS": return AppStoreConnectLocalization.string("visionOS App")
        default: return AppStoreConnectLocalization.string("%@ App", app.platformLabel)
        }
    }

    private func isVersionSelected(_ version: AppStoreVersion) -> Bool {
        guard let selected = viewModel.selectedVersion else { return false }
        return version.id == selected.id || version.versionString == selected.versionString
    }
}
