import SwiftUI
import MagicKit

/// 智谱 GLM 配额详情视图（在 popover 中显示）
struct ZhipuQuotaDetailView: View {
    let status: ZhipuQuotaStatus

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // 标题
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16))
                    .foregroundColor(DesignTokens.Color.semantic.primary)

                Text(String(localized: "Zhipu GLM Quota", table: "ZhipuQuotaStatusBar"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                Spacer()
            }

            Divider()

            switch status {
            case .loading:
                loadingContent
            case .success(let data):
                quotaContent(data)
            case .authError:
                authErrorContent
            case .unavailable:
                unavailableContent
            }
        }
    }

    /// 加载内容
    private var loadingContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .scaleEffect(0.8)

            Text(String(localized: "Loading...", table: "ZhipuQuotaStatusBar"))
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// 配额内容
    private func quotaContent(_ data: ZhipuQuotaData) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // 等级
            QuotaInfoRow(
                label: String(localized: "Level", table: "ZhipuQuotaStatusBar"),
                value: data.levelDisplay
            )

            // 进度条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "Usage Progress", table: "ZhipuQuotaStatusBar"))
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Spacer()

                    Text("\(data.usedPercent)%")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }

                ProgressView(value: Double(data.usedPercent) / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(data.usedPercent)))

                HStack {
                    Text(String(localized: "Remaining \(data.leftPercent)%", table: "ZhipuQuotaStatusBar"))
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Spacer()

                    Text(String(localized: "Total 5 hours", table: "ZhipuQuotaStatusBar"))
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }

            Divider()

            // 重置时间（显示完整日期和相对时间）
            VStack(alignment: .leading, spacing: 4) {
                QuotaInfoRow(
                    label: String(localized: "Reset Time", table: "ZhipuQuotaStatusBar"),
                    value: data.resetTime
                )
                Text("（\(data.resetTimeRelative)）")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
            }

            Divider()

            // MCP 每月额度
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "MCP Monthly Quota", table: "ZhipuQuotaStatusBar"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignTokens.Color.semantic.textPrimary)

                    Spacer()
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    // 剩余额度百分比
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Remaining", table: "ZhipuQuotaStatusBar"))
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("\(data.mcpLeftPercent)%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(DesignTokens.Color.semantic.success)
                    }

                    Spacer()

                    // 重置时间
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "Reset", table: "ZhipuQuotaStatusBar"))
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text(data.mcpResetTime)
                            .font(.system(size: 11))
                            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                        Text("(\(data.mcpResetTimeRelative))")
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Color.semantic.textTertiary)
                    }
                }
                .padding(12)
                .background(Color(white: 0.95).opacity(0.1))
                .cornerRadius(8)
            }

            // 状态说明
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Description", table: "ZhipuQuotaStatusBar"))
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Text(String(localized: "Zhipu GLM Coding Plan uses a 5-hour rolling window quota. Quota gradually recovers after use.", table: "ZhipuQuotaStatusBar"))
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                    .lineLimit(3)
            }
        }
    }

    /// 认证错误内容
    private var authErrorContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text(String(localized: "Auth expired", table: "ZhipuQuotaStatusBar"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text(String(localized: "Please check if Zhipu AI API Key is correctly configured", table: "ZhipuQuotaStatusBar"))
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// 不可用内容
    private var unavailableContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(DesignTokens.Color.semantic.warning)

            Text(String(localized: "Quota unavailable", table: "ZhipuQuotaStatusBar"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text(String(localized: "Please check network connection or try again later", table: "ZhipuQuotaStatusBar"))
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.lg)
    }

    /// 根据百分比返回进度条颜色
    private func progressColor(_ percent: Int) -> Color {
        if percent < 50 {
            return .green
        } else if percent < 80 {
            return .orange
        } else {
            return .red
        }
    }
}

/// 配额信息行
struct QuotaInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 70, alignment: .leading)

            Text(value)
                .font(.system(size: 12))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Spacer()
        }
    }
}
