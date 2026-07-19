import LumiUI
import SwiftUI

struct GeneralSettingsPage: View {
    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: "通用", titleAlignment: .leading) {
                    AppEmptyState(
                        icon: "gearshape",
                        title: "通用设置将在插件迁移后可用"
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
