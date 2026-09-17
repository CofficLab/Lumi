import LumiUI
import SwiftUI

/// 主工具栏右侧的版本与语言选择器。
///
/// 这两个下拉选择从 DistributionPage 顶部移到全局工具栏，让内容区顶部
/// 不再被一行工具栏挤占，直接从第一个内容区块开始。
struct AppStoreConnectDistributionToolbarView: View {
    @ObservedObject var viewModel: VM

    var body: some View {
        if viewModel.selectedApp != nil,
           viewModel.selectedVersion != nil,
           viewModel.page == .distribution {
            HStack(spacing: 12) {
                versionPicker
                if !viewModel.localizations.isEmpty {
                    localizationPicker
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

    private var localizationPicker: some View {
        ToolbarSelectControl(
            title: viewModel.selectedLocalization?.locale
                ?? AppStoreConnectLocalization.string("Locale"),
            systemImage: "globe",
            maxTitleWidth: 120
        ) {
            LocalizationOptionsView(viewModel: viewModel)
        }
    }

    private var versionSelectionTitle: String {
        guard let version = viewModel.selectedVersion else {
            return AppStoreConnectLocalization.string("Select a version")
        }
        return versionDisplayTitle(version)
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

    private var groupedVersions: [(platform: String, versions: [AppStoreVersion])] {
        let grouped = Dictionary(grouping: viewModel.versions, by: { $0.platform.normalizedASCPlatform })
        return grouped
            .map { (platform: $0.key, versions: $0.value.sorted { $0.versionString > $1.versionString }) }
            .sorted { lhs, rhs in
                platformSortIndex(lhs.platform) < platformSortIndex(rhs.platform)
            }
    }

    private func platformSortIndex(_ platform: String) -> Int {
        let platformOrder = ["IOS", "MAC_OS", "TV_OS", "VISION_OS"]
        return platformOrder.firstIndex(of: platform.normalizedASCPlatform) ?? Int.max
    }
}
