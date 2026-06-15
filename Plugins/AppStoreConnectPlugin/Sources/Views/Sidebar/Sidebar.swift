import LumiUI
import SwiftUI

struct Sidebar: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sidebarSection(AppStoreConnectLocalization.string("General")) {
                sidebarButton(.account)
                sidebarButton(.apps)
            }

            if viewModel.selectedApp != nil {
                Divider()
                    .padding(.vertical, 6)

                versionsSection
            }

            Spacer(minLength: 0)

            Divider()
            sidebarButton(.xcodeCloud)
                .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
    }

    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
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
            .padding(.top, 6)

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

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)

            content()
        }
    }

    private func sidebarButton(_ page: AppStoreConnectViewModel.Page) -> some View {
        Button {
            viewModel.navigate(to: page)
        } label: {
            Label(page.title, systemImage: page.systemImage)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(viewModel.page == page ? Color.accentColor.opacity(0.16) : Color.clear)
    }
}

private extension AppStoreApp {
    var platformLabel: String {
        switch platform.normalizedASCPlatform {
        case "MAC_OS": return "macOS"
        case "IOS": return "iOS"
        case "TV_OS": return "tvOS"
        case "VISION_OS": return "visionOS"
        default: return platform
        }
    }
}
