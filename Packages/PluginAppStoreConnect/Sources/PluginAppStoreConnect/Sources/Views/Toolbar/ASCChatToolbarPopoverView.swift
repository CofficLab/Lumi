import LumiUI
import SwiftUI

/// Chat Toolbar 弹层：展示当前项目对应 App 的 App Store 版本列表。
///
/// 结构：
/// - 头部：App 名称 + Bundle ID + 刷新按钮；
/// - 正文：按平台分组的版本行（版本号 + 状态），点击可「加入对话」；
/// - 空态：未绑定 App / 未配置凭证 / 无版本 三种。
struct ASCChatToolbarPopoverView: View {
    @LumiTheme private var theme
    @ObservedObject var viewModel: ASCChatToolbarViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            AppDivider()
            content
        }
        .frame(width: 380)
        .frame(minHeight: 220, maxHeight: 460)
        .background(theme.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.app?.name ?? AppStoreConnectLocalization.string("AppStoreConnect"))
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                if let bundleID = viewModel.app?.bundleID {
                    Text(bundleID)
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()

            if viewModel.isLoading {
                ProgressView().controlSize(.mini)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .help(AppStoreConnectLocalization.string("Refresh"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let errorMessage = viewModel.errorMessage, viewModel.versions.isEmpty {
            ASCChatToolbarErrorBanner(message: errorMessage)
        } else if let app = viewModel.app {
            if viewModel.versions.isEmpty {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    AppEmptyState(
                        icon: "shippingbox",
                        title: AppStoreConnectLocalization.string("No versions loaded"),
                        description: AppStoreConnectLocalization.string(
                            "This app has no App Store versions on App Store Connect yet."
                        )
                    )
                    .frame(maxWidth: .infinity, minHeight: 140)
                }
            } else {
                versionList
            }
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 140)
        } else {
            AppEmptyState(
                icon: "link",
                title: AppStoreConnectLocalization.string("No App Store Connect App"),
                description: AppStoreConnectLocalization.string(
                    "This project is not linked to an App Store Connect app. Add .lumi/app-store-connect/app.json or an Xcode project with a bundle identifier."
                )
            )
            .frame(maxWidth: .infinity, minHeight: 140)
        }
    }

    private var versionList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedVersions, id: \.platform) { group in
                    AppSectionLabel(group.platformLabel)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    ForEach(group.versions) { version in
                        ASCChatToolbarVersionRow(version: version)
                        AppDivider()
                    }
                }
            }
            .padding(.bottom, 6)
        }
    }

    // MARK: - Data

    private var groupedVersions: [(platform: String, platformLabel: String, versions: [AppStoreVersion])] {
        let order = ["IOS", "MAC_OS", "TV_OS", "VISION_OS"]
        let grouped = Dictionary(grouping: viewModel.versions) { $0.platform.normalizedASCPlatform }
        return grouped
            .map { (platform: $0.key, platformLabel: Self.platformLabel($0.key), versions: $0.value) }
            .sorted { lhs, rhs in
                let lhsIndex = order.firstIndex(of: lhs.platform) ?? Int.max
                let rhsIndex = order.firstIndex(of: rhs.platform) ?? Int.max
                if lhsIndex != rhsIndex { return lhsIndex < rhsIndex }
                return lhs.platform < rhs.platform
            }
    }

    private static func platformLabel(_ platform: String) -> String {
        switch platform {
        case "MAC_OS": return AppStoreConnectLocalization.string("macOS")
        case "IOS": return AppStoreConnectLocalization.string("iOS")
        case "TV_OS": return AppStoreConnectLocalization.string("tvOS")
        case "VISION_OS": return AppStoreConnectLocalization.string("visionOS")
        default: return platform
        }
    }
}
