import LocalizationKit
import LumiUI
import SwiftUI

/// 插件管理页头部统计:展示当前可配置插件总数与已启用数量。
///
/// 由 `PluginManagementView` 内部使用;标记 `internal` 以允许跨文件引用
/// (若标记 `fileprivate`,其他 Swift 文件中无法解析)。
struct PluginManagementHeader: View {
    @LumiTheme private var theme

    /// 可配置插件总数(与列表口径一致)。
    let totalCount: Int

    /// 当前已启用的可配置插件数。
    let enabledCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Label(
                String(format: PluginManagerText.string(PluginManagerText.pluginsCount), totalCount),
                systemImage: "puzzlepiece.extension"
            )
            Text(String(format: PluginManagerText.string(PluginManagerText.enabledCount), enabledCount))
            Spacer()
        }
        .font(.appCaption)
        .foregroundStyle(theme.textSecondary)
    }
}
