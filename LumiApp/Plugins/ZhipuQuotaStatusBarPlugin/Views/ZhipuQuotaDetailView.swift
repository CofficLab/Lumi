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

                Text("智谱 GLM 配额")
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

            Text("正在获取配额信息...")
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
            QuotaInfoRow(label: "等级", value: data.levelDisplay)

            // 进度条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("使用进度")
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
                    Text("剩余 \(data.leftPercent)%")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                    Spacer()

                    Text("总时长 5 小时")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                }
            }

            Divider()

            // 重置时间
            QuotaInfoRow(label: "重置时间", value: data.resetTime)

            // 状态说明
            VStack(alignment: .leading, spacing: 4) {
                Text("说明")
                    .font(.system(size: 12))
                    .foregroundColor(DesignTokens.Color.semantic.textSecondary)

                Text("智谱 GLM Coding Plan 采用 5 小时滚动窗口配额。配额会在使用后逐渐恢复。")
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

            Text("认证已过期")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("请检查智谱 AI API Key 是否正确配置")
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

            Text("配额信息不可用")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)

            Text("请检查网络连接或稍后重试")
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
