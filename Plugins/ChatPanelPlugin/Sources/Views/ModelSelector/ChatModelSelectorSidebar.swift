import LumiCoreKit
import LumiUI
import SwiftUI

struct ChatModelSelectorSidebar: View {
    @LumiTheme private var theme

    let providers: [LumiLLMProviderInfo]
    let selectedProviderID: String?
    @Binding var selectedTab: ChatModelSelectorTab

    var body: some View {
        VStack(spacing: 4) {
            quickTabButton(tab: .current, icon: "scope", title: "Current Provider")
            quickTabButton(tab: .frequent, icon: "clock.arrow.circlepath", title: "Frequent")
            quickTabButton(tab: .fast, icon: "bolt.fill", title: "Fast")
            quickTabButton(tab: .auto, icon: "wand.and.sparkles", title: "Auto")
            quickTabButton(tab: .availability, icon: "network", title: "Availability")

            ChatDivider(axis: .horizontal)
                .padding(.vertical, 4)

            Text("Providers", bundle: .module)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(theme.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(providers) { provider in
                        providerTabButton(provider)
                    }
                }
            }

            ChatDivider(axis: .horizontal)
                .padding(.vertical, 4)

            quickTabButton(tab: .all, icon: "globe", title: "All")
        }
        .padding()
    }

    private func quickTabButton(tab: ChatModelSelectorTab, icon: String, title: String) -> some View {
        AppListRow(isSelected: selectedTab == tab, action: { selectedTab = tab }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 16)

                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
        }
    }

    private func providerTabButton(_ provider: LumiLLMProviderInfo) -> some View {
        let tab = ChatModelSelectorTab.provider(provider.id)

        return AppListRow(isSelected: selectedTab == tab, action: { selectedTab = tab }) {
            HStack(spacing: 4) {
                Image(systemName: "cloud")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 16)

                Text(provider.displayName)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                if selectedProviderID == provider.id {
                    Text("Active", bundle: .module)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.primary)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.primary.opacity(0.12))
                        )
                }

                Text("\(provider.availableModels.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
