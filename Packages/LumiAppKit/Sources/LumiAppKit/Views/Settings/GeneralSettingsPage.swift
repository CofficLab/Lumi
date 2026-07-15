import LumiCoreKit
import LumiLocalizationKit
import LumiUI
import SwiftUI

struct GeneralSettingsPage: View {
    var body: some View {
        AppSettingsContentScaffold(maxContentWidth: nil) {
            VStack(alignment: .leading, spacing: 24) {
                AppSettingSection(title: String(localized: "Onboarding", bundle: .module), titleAlignment: .leading) {
                    AppSettingRow(
                        title: String(localized: "Replay Onboarding", bundle: .module),
                        description: String(localized: "Replay the first-run onboarding flow.", bundle: .module),
                        icon: "graduationcap"
                    ) {
                        AppButton(String(localized: "Start", bundle: .module), systemImage: "arrow.right", style: .secondary, size: .small) {
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
