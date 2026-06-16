import LumiUI
import SwiftUI

struct Sidebar: View {
    @ObservedObject var viewModel: AppStoreConnectViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.selectedApp != nil {
                SidebarVersionsSection(viewModel: viewModel)
                    .padding(.top, 6)
            }

            Spacer(minLength: 0)

            Divider()
            sidebarSection(AppStoreConnectLocalization.string("General")) {
                sidebarButton(.account)
                sidebarButton(.apps)
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.regularMaterial)
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

extension AppStoreApp {
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
