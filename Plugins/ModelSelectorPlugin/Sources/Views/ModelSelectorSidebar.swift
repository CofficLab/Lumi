
import LumiChatKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ModelSelectorSidebar: View {
    @LumiTheme private var theme
    @ObservedObject var availability: ModelAvailabilityState

    let providers: [LumiLLMProviderInfo]
    let selectedProviderID: String?
    @Binding var selectedTab: ModelSelectorTab
    let dailyUsage: [String: ModelDailyTokenSeries]

    var body: some View {
        VStack(spacing: 4) {
            quickTabButton(tab: .frequent, icon: "clock.arrow.circlepath", title: "Frequent")
            quickTabButton(tab: .current, icon: "scope", title: "Current Provider")
            quickTabButton(tab: .fast, icon: "bolt.fill", title: "Fast")
            quickTabButton(tab: .auto, icon: "wand.and.sparkles", title: "Auto")

            ModelSelectorDivider(axis: .horizontal)
                .padding(.vertical, 4)

            Text(verbatim: LumiPluginLocalization.string("Providers", bundle: .module))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(providers) { provider in
                        ProviderCard(
                            availability: availability,
                            provider: provider,
                            isSelected: selectedTab == .provider(provider.id),
                            isActive: selectedProviderID == provider.id,
                            onSelect: { selectedTab = .provider(provider.id) },
                            dailyUsage: dailyUsage
                        )
                    }
                }
            }

            ModelSelectorDivider(axis: .horizontal)
                .padding(.vertical, 4)

            quickTabButton(tab: .all, icon: "globe", title: "All")
        }
        .padding()
    }

    private func quickTabButton(tab: ModelSelectorTab, icon: String, title: String) -> some View {
        AppListRow(isSelected: selectedTab == tab, action: { selectedTab = tab }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 16)

                Text(verbatim: LumiPluginLocalization.string(title, bundle: .module))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
        }
    }
}
