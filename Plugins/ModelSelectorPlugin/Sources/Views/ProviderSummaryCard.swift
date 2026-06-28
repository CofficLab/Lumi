import LLMAvailabilityPlugin
import LumiCoreKit
import LumiUI
import SwiftUI

/// 供应商摘要卡片，显示在模型列表顶部，展示模型统计信息、刷新操作和状态消息
struct ProviderSummaryCard: View {
    @LumiTheme private var theme
    @ObservedObject private var availabilityStore = LLMAvailabilityStore.shared

    let provider: LumiLLMProviderInfo
    let isChecking: Bool
    let onRefresh: () -> Void
    let statusMessage: String?
    let statusMessageColor: Color?

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

    private var unavailableCount: Int {
        totalModelCount - availableModelCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Icon with availability indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: provider.isLocal ? "cpu" : "cloud")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                    Circle()
                        .fill(isProviderAvailable ? .green : .red)
                        .frame(width: 10, height: 10)
                        .offset(x: 10, y: 10)
                }

                // Provider info and stats
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        Label("\(totalModelCount)", systemImage: "number")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(theme.textSecondary)

                        Label("\(availableModelCount)", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)

                        if unavailableCount > 0 {
                            Label("\(unavailableCount)", systemImage: "xmark.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textTertiary)
                        }
                    }
                }

                Spacer()

                // Refresh button and status badge
                HStack(spacing: 12) {
                    // Refresh Button
                    if isChecking {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Button {
                            onRefresh()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Re-check availability")
                    }

                    // Status Badge (e.g., 7/9)
                    statusBadge
                }
            }

            // Optional status message (e.g., "API Key missing")
            if let message = statusMessage, let color = statusMessageColor {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundColor(color)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Components

    @ViewBuilder
    private var statusBadge: some View {
        if isProviderAvailable {
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(verbatim: "\(availableModelCount)/\(totalModelCount)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.green)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.green.opacity(0.1))
            )
        } else {
            HStack(spacing: 4) {
                Circle()
                    .fill(theme.textTertiary)
                    .frame(width: 6, height: 6)
                Text("不可用")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textTertiary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(theme.textTertiary.opacity(0.1))
            )
        }
    }

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(theme.background.opacity(0.5))
    }

    private var iconBackgroundColor: Color {
        isProviderAvailable ? .green.opacity(0.15) : theme.textTertiary.opacity(0.15)
    }

    private var iconColor: Color {
        isProviderAvailable ? .green : theme.textSecondary
    }
}
