import SwiftUI
import LumiUI
import KernelLumi

/// ``MainView`` 空状态时的顶部 Header。
///
/// 居中展示：
/// - 数据库图标（`cylinder.split.1x2`）
/// - 标题文案「Select a database to connect」
/// - 副标题文案与说明
/// - 一个「Add Connection」主按钮，点击触发 `onAddConnection` 回调
///
/// 通过回调而不是绑定 `showAddConfigSheet` 来降低与父视图的耦合，
/// 让本视图可在其他空状态场景（例如首次启动引导）中复用。
struct MainEmptyStateHeaderView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    // MARK: - Properties

    /// 点击「Add Connection」按钮时触发的回调。
    let onAddConnection: () -> Void

    // MARK: - Initialization

    init(onAddConnection: @escaping () -> Void) {
        self.onAddConnection = onAddConnection
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cylinder.split.1x2")
                .font(.appLargeTitle)
                .foregroundColor(theme.textSecondary)
            Text(LumiPluginLocalization.string("Select a database to connect", bundle: .module))
                .font(.appTitle)
                .foregroundColor(theme.textSecondary)
            Text(LumiPluginLocalization.string("Pick a saved connection below, or add a new one to get started.", bundle: .module))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            AppButton(
                LumiPluginLocalization.string("Add Connection", bundle: .module),
                systemImage: "plus",
                style: .primary,
                fillsWidth: false,
                action: onAddConnection
            )
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview("Empty Header") {
    MainEmptyStateHeaderView(onAddConnection: {})
        .frame(width: 480, height: 320)
}
#endif