import SwiftUI
import LLMKit
import LumiUI

/// 模型选择器 Tab 侧边栏
struct ModelSelectorTabSidebar: View {
    @ObservedObject private var availabilityStore = LLMAvailabilityStore.shared

    /// 所有已注册的供应商
    let providers: [LLMProviderInfo]

    /// 当前选中的 Tab
    @Binding var selectedTab: ModelSelectorTab

    var body: some View {
        VStack(spacing: 4) {
            // MARK: - 上半区：快捷 Tab

            quickTabButton(tab: .current, icon: "scope", title: String(localized: "Current Provider", table: "AgentChat"))
            quickTabButton(tab: .frequent, icon: "clock.arrow.circlepath", title: String(localized: "Frequent", table: "AgentChat"))
            quickTabButton(tab: .fast, icon: "bolt.fill", title: String(localized: "Fast", table: "AgentChat"))
            quickTabButton(tab: .auto, icon: "wand.and.sparkles", title: "Auto")
            quickTabButton(
                tab: .availability,
                icon: "network",
                title: String(localized: "Availability", table: "LLMAvailability"),
                trailingText: availabilitySummaryText
            )

            Divider()
                .padding(.vertical, 4)

            // MARK: - 下半区：供应商列表（可滚动）

            Text(String(localized: "Providers", table: "AgentChat"))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "98989E"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(providers) { provider in
                        providerTabButton(provider: provider)
                    }
                }
            }

            Divider()
                .padding(.vertical, 4)

            quickTabButton(tab: .all, icon: "globe", title: String(localized: "All", table: "AgentChat"))
        }
        .padding()
    }

    // MARK: - 快捷 Tab 按钮

    /// 快捷 Tab 按钮（当前/常用/较快/全部）
    private func quickTabButton(
        tab: ModelSelectorTab,
        icon: String,
        title: String,
        trailingText: String? = nil
    ) -> some View {
        AppListRow(isSelected: selectedTab == tab, action: { selectedTab = tab }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 16, alignment: .center)
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                Spacer()
                if let trailingText {
                    Text(trailingText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - 供应商 Tab 按钮

    /// 单个供应商的 Tab 按钮
    private func providerTabButton(provider: LLMProviderInfo) -> some View {
        let tab = ModelSelectorTab.provider(provider.id)
        return AppListRow(isSelected: selectedTab == tab, action: { selectedTab = tab }) {
            HStack(spacing: 4) {
                Image(systemName: provider.isLocal ? "laptopcomputer" : "cloud")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 16, alignment: .center)
                Text(provider.displayName)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                Spacer()

                if let countText = availabilityCountText(for: provider.id) {
                    Text(countText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .lineLimit(1)
                }

                if let websiteURL = provider.websiteURL,
                   let url = URL(string: websiteURL) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 10))
                            .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5").opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help(websiteURL)
                }
            }
        }
    }

    private var availabilitySummaryText: String? {
        AvailabilityService.summary(store: availabilityStore).displayText
    }

    private func availabilityCountText(for providerId: String) -> String? {
        AvailabilityService.providerCountText(providerId: providerId, store: availabilityStore)
    }
}
