import Combine
import Foundation

/// 供应商页面的两个范围：云端 / 本地。
///
/// 「云端供应商」与「本地供应商」原本是两个独立的设置入口，现在合并成一个页面，
/// 由头部行右上角的分段控件切换当前展示哪一类。
enum ProviderSettingsScope: String, CaseIterable, Identifiable, Equatable {
    case cloud
    case local

    var id: String { rawValue }

    /// 分段控件上的页签标题。
    var title: String {
        switch self {
        case .cloud: pluginLocalization.string("Cloud")
        case .local: pluginLocalization.string("Local")
        }
    }

    /// 该范围在页面里使用的图标（表头、列表行图标）。
    var systemImage: String {
        switch self {
        case .cloud: "cloud"
        case .local: "cpu"
        }
    }
}

/// 合并后的供应商页的范围状态。
///
/// 两个范围各自持有一个 `ProviderSettingsPageViewModel`（搜索词、选中项互不干扰），
/// 这里只负责「当前展示哪一个」。
@MainActor
final class ProviderSettingsScopeViewModel: ObservableObject {
    /// 当前范围。默认停在云端。
    @Published private(set) var scope: ProviderSettingsScope = .cloud

    let cloudViewModel: ProviderSettingsPageViewModel
    let localViewModel: ProviderSettingsPageViewModel

    init(
        cloudViewModel: ProviderSettingsPageViewModel,
        localViewModel: ProviderSettingsPageViewModel
    ) {
        self.cloudViewModel = cloudViewModel
        self.localViewModel = localViewModel
    }

    /// 当前范围对应的 ViewModel（左侧列表与右侧详情都读它）。
    var activeViewModel: ProviderSettingsPageViewModel {
        switch scope {
        case .cloud: cloudViewModel
        case .local: localViewModel
        }
    }

    /// 切换范围。
    ///
    /// 切换后立刻同步选中项：新范围第一次展示时还没有选中项，
    /// 右侧详情会空着——补上该范围的第一项，详情不悬空。
    func selectScope(_ newScope: ProviderSettingsScope) {
        guard scope != newScope else { return }
        scope = newScope
        activeViewModel.synchronizeSelection()
    }
}
