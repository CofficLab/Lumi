import LLMAvailabilityPlugin
import LumiCoreKit
import LumiUI
import SwiftUI

/// 卡片式供应商信息展示组件。
///
/// 用于 Model Selector 左侧栏的供应商列表。
struct ProviderCard: View {
    @LumiTheme private var theme
    @ObservedObject private var availabilityStore = LLMAvailabilityStore.shared

    let provider: LumiLLMProviderInfo
    let isSelected: Bool
    let isActive: Bool
    let onSelect: () -> Void

    // MARK: - Derived

    private var totalModelCount: Int {
        provider.availableModels.count
    }

    private var availableModelCount: Int {
        provider.availableModels.filter { model in
            let status = availabilityStore.status(providerId: provider.id, modelId: model)
            return status == .available
        }.count
    }

    private var isProviderAvailable: Bool {
        availableModelCount > 0
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? theme.primary.opacity(0.06) : theme.surface)
    }

    var body: some View {
        Button(action: onSelect) {
            // Header row: icon + name + active badge + count
            HStack(spacing: 8) {
                // Icon with availability indicator
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
                    Text(verbatim: "Active")
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
