import LumiUI
import SwiftUI

struct SidebarVersionsSection: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

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
        return AppStoreConnectLocalization.string("%@ App", app.platformLabel)
    }

    private func isVersionSelected(_ version: AppStoreVersion) -> Bool {
        guard let selected = viewModel.selectedVersion else { return false }
        return version.id == selected.id || version.versionString == selected.versionString
    }
}
