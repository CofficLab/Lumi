import LumiUI
import SwiftUI

/// 外观设置页（最小实现）
///
/// 主题选择功能将在后续 LumiUI 服务迁移后恢复。
struct AppearanceSettingsPage: View {
    @LumiTheme private var theme

    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: "外观", titleAlignment: .leading) {
                    AppEmptyState(
                        icon: "paintbrush",
                        title: "主题设置将在插件迁移后可用"
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
