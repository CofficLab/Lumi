import SwiftUI

/// 模型选择器 Tab 侧边栏
struct ModelSelectorTabSidebar: View {
    /// 所有已注册的供应商
    let providers: [LLMProviderInfo]

    /// 当前选中的 Tab
    @Binding var selectedTab: ModelSelectorTab
    /// 当前 hover 的 Tab
    @Binding var hoveringTab: ModelSelectorTab?

    var body: some View {
        VStack(spacing: 4) {
            // MARK: - 上半区：快捷 Tab

            quickTabButton(tab: .current, icon: "scope", title: String(localized: "Current Provider", table: "AgentChat"))
            quickTabButton(tab: .frequent, icon: "clock.arrow.circlepath", title: String(localized: "Frequent", table: "AgentChat"))
            quickTabButton(tab: .fast, icon: "bolt.fill", title: String(localized: "Fast", table: "AgentChat"))

            Divider()
                .padding(.vertical, 4)

            // MARK: - 下半区：供应商列表（可滚动）

            Text(String(localized: "Providers", table: "AgentChat"))
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "98989E"))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)

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
        .padding(8)
    }

    // MARK: - 快捷 Tab 按钮

    /// 快捷 Tab 按钮（当前/常用/较快/全部）
    private func quickTabButton(tab: ModelSelectorTab, icon: String, title: String) -> some View {
        Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 16, alignment: .center)
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tabBackgroundColor(for: tab))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveringTab = hovering ? tab : nil
        }
    }

    // MARK: - 供应商 Tab 按钮

    /// 单个供应商的 Tab 按钮
    private func providerTabButton(provider: LLMProviderInfo) -> some View {
        let tab = ModelSelectorTab.provider(provider.id)
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: 8) {
                Image(systemName: provider.isLocal ? "laptopcomputer" : "cloud")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    .frame(width: 16, alignment: .center)
                Text(provider.displayName)
                    .font(.system(size: 15, weight: .regular))
                    .lineLimit(1)
                Spacer()

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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tabBackgroundColor(for: tab))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveringTab = hovering ? tab : nil
        }
    }

    // MARK: - Helper

    /// Tab 背景色
    private func tabBackgroundColor(for tab: ModelSelectorTab) -> Color {
        if selectedTab == tab {
            return Color.accentColor.opacity(0.15)
        }
        if hoveringTab == tab {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }
}
