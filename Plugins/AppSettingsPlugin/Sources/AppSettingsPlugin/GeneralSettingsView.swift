import LocalizationKit
import LumiKernel
import LumiUI
import SwiftUI

/// "通用"设置页(原 LumiFactory 的 GeneralSettingsPage)。
struct GeneralSettingsView: View {
    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(
                    title: LumiLocalization.string("Onboarding", bundle: .module),
                    titleAlignment: .leading
                ) {
                    AppSettingRow(
                        title: LumiLocalization.string("Replay Onboarding", bundle: .module),
                        description: LumiLocalization.string("Replay the first-run onboarding flow.", bundle: .module),
                        icon: "graduationcap"
                    ) {
                        AppButton(
                            LumiLocalization.string("Start", bundle: .module),
                            systemImage: "arrow.right",
                            style: .secondary,
                            size: .small
                        ) {
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
