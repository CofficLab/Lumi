import SwiftUI

/// 供应商设置页：云端与本地供应商合并到一个界面。
///
/// 头部行右上角放「云端 / 本地」分段控件切换范围——与「工具」页的模式分段控件
/// 同一个位置（头部行最右侧）。切换范围时左侧列表与右侧详情一起更换。
///
/// 两个范围各自持有独立的 `ProviderSettingsPageViewModel`，搜索词与选中项
/// 互不干扰：来回切不会把上一个范围的选中态带过去。
@MainActor
public struct ProviderSettingsPage: View {
    @ObservedObject private var scopeViewModel: ProviderSettingsScopeViewModel

    init(scopeViewModel: ProviderSettingsScopeViewModel) {
        self.scopeViewModel = scopeViewModel
    }

    public var body: some View {
        ProviderSettingsPageContent(
            viewModel: scopeViewModel.activeViewModel,
            scope: Binding(
                get: { scopeViewModel.scope },
                set: { scopeViewModel.selectScope($0) }
            )
        )
    }
}
