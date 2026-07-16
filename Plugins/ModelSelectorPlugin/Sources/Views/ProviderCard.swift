
import LumiChatKit
import LumiCoreKit
import LumiLocalizationKit
import LumiUI
import SwiftUI

/// 卡片式供应商信息展示组件。
///
/// 用于 Model Selector 左侧栏的供应商列表。
struct ProviderCard: View {
    @LumiTheme private var theme
    @ObservedObject var availability: ModelAvailabilityState

    let provider: LumiLLMProviderInfo
    let isSelected: Bool
    let isActive: Bool
    let onSelect: () -> Void
    var dailyUsage: [String: ModelDailyTokenSeries] = [:]

    // MARK: - Derived

    private var totalModelCount: Int {
        provider.availableModels.count
    }

    private var availableModelCount: Int {
        availability.availableCount(for: provider)
    }

    private var isProviderAvailable: Bool {
        availableModelCount > 0
    }

    private var providerDailyUsage: [String: ModelDailyTokenSeries] {
        dailyUsage.filter { $0.value.providerID == provider.id }
    }

    private var hasDailyUsage: Bool {
        !providerDailyUsage.isEmpty && providerDailyUsage.values.contains { $0.hasData }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? theme.primary.opacity(0.06) : theme.surface)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(theme.surface)
                        .frame(width: 28, height: 28)
                    Image(systemName: provider.isLocal ? "cpu" : "cloud")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.primary)
                    Circle()
                        .fill(isProviderAvailable ? .green : .red)
                        .frame(width: 8, height: 8)
                        .offset(x: 8, y: 8)
                }

                Text(provider.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isSelected ? theme.primary : theme.textPrimary)
                    .lineLimit(1)

                if isActive {
                    Text(verbatim: LumiPluginLocalization.string("Active", bundle: .module))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.primary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(theme.primary.opacity(0.15))
                        )
                }

                Spacer()
            }
            .padding(10)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        isSelected ? theme.primary.opacity(0.3) : theme.divider,
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
