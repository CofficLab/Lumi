import SwiftUI
import LumiUI

/// 智谱 GLM 配额详情视图（在 popover 中显示）
struct ZhipuQuotaDetailView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    let status: ZhipuQuotaStatus
    let onRefresh: (() -> Void)?

    @State private var isRefreshing: Bool = false

    init(status: ZhipuQuotaStatus, onRefresh: (() -> Void)? = nil) {
        self.status = status
        self.onRefresh = onRefresh
    }

    var body: some View {
        StatusBarPopoverScaffold(
            title: String(localized: "Zhipu GLM Quota", table: "Zhipu"),
            systemImage: "chart.bar.fill"
        ) {
            AppIconButton(systemImage: "arrow.clockwise") {
                triggerRefresh()
            }
            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
            .disabled(isRefreshing)
        } content: {
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
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)

            Text(String(localized: "Loading...", table: "Zhipu"))
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    /// 配额内容
    private func quotaContent(_ data: ZhipuQuotaData) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 等级
            GlassKeyValueRow(
                label: String(localized: "Level", table: "Zhipu"),
                value: data.levelDisplay,
                labelWidth: 70
            )

            // 进度条
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "Usage Progress", table: "Zhipu"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)

                    Spacer()

                    Text("\(data.usedPercent)%")
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }

                ProgressView(value: Double(data.usedPercent) / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor(data.usedPercent)))

                HStack {
                    Text(String(localized: "Remaining \(data.leftPercent)%", table: "Zhipu"))
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)

                    Spacer()

                    Text(String(localized: "Total 5 hours", table: "Zhipu"))
                        .font(.appMicro)
                        .foregroundColor(theme.textSecondary)
                }
            }

            GlassDivider()

            // 重置时间（显示完整日期和相对时间）
            VStack(alignment: .leading, spacing: 4) {
                GlassKeyValueRow(
                    label: String(localized: "Reset Time", table: "Zhipu"),
                    value: data.resetTime,
                    labelWidth: 70
                )
                Text("（\(data.resetTimeRelative)）")
                    .font(.appMicro)
                    .foregroundColor(theme.textSecondary)
            }

            GlassDivider()

            // MCP 每月额度
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(localized: "MCP Monthly Quota", table: "Zhipu"))
                        .font(.appCaptionEmphasized)
                        .foregroundColor(theme.textPrimary)

                    Spacer()
                }

                HStack(spacing: 16) {
                    // 剩余额度百分比
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Remaining", table: "Zhipu"))
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                        Text("\(data.mcpLeftPercent)%")
                            .font(.appTitle)
                            .foregroundColor(theme.success)
                    }

                    Spacer()

                    // 重置时间
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(localized: "Reset", table: "Zhipu"))
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                        Text(data.mcpResetTime)
                            .font(.appMicro)
                            .foregroundColor(theme.textSecondary)
                        Text("(\(data.mcpResetTimeRelative))")
                            .font(.appMicro)
                            .foregroundColor(theme.textTertiary)
                    }
                }
                .padding(12)
                .appSurface(style: .subtle, cornerRadius: 8)
            }
        }
    }

    /// 认证错误内容
    private var authErrorContent: some View {
        AppEmptyState(
            icon: "exclamationmark.triangle.fill",
            title: LocalizedStringKey(String(localized: "Auth expired", table: "Zhipu")),
            description: LocalizedStringKey(String(localized: "Please check if Zhipu AI API Key is correctly configured", table: "Zhipu"))
        )
    }

    /// 不可用内容
    private var unavailableContent: some View {
        AppEmptyState(
            icon: "exclamationmark.triangle",
            title: LocalizedStringKey(String(localized: "Quota unavailable", table: "Zhipu")),
            description: LocalizedStringKey(String(localized: "Please check network connection or try again later", table: "Zhipu"))
        )
    }

    /// 根据百分比返回进度条颜色
    private func progressColor(_ percent: Int) -> Color {
        if percent < 50 {
            return theme.success
        } else if percent < 80 {
            return theme.warning
        } else {
            return theme.error
        }
    }

    /// 触发刷新
    private func triggerRefresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        onRefresh?()
        // 动画完成后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isRefreshing = false
        }
    }
}
