import LumiCoreKit
import LumiUI
import SwiftUI

struct GeneralSettingsPage: View {
    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: "新手引导", titleAlignment: .leading) {
                    AppSettingRow(
                        title: "重新查看新手引导",
                        description: "再次打开首次使用引导流程",
                        icon: "graduationcap"
                    ) {
                        AppButton("开始", systemImage: "arrow.right", style: .secondary, size: .small) {
                            NotificationCenter.default.post(
                                name: .lumiShowOnboarding,
                                object: nil,
                                userInfo: [LumiOnboardingNotification.resetKey: true]
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
