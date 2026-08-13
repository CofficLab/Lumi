import SwiftUI

/// 落地页顶部 Hero 横幅。
///
/// 一张全宽圆角渐变卡片,包含图标徽标、营销标语(`tagline`)、特性胶囊
/// (`chips`)以及可选的迷你统计(`metrics`)。视觉上承担「头图」的职责,
/// 但不再重复外层详情页已有的插件名/描述,而是用一句更有感染力的标语。
///
/// `metrics` 复用 `AppPluginPosterMetric`(value + label),与插件海报保持一致。
public struct LandingHero: View {
    @LumiTheme private var theme

    private let icon: String
    private let tint: Color?
    private let tagline: String
    private let chips: [String]
    private let metrics: [AppPluginPosterMetric]

    /// 主题强调色(驱动渐变与图标)。默认跟随主题 `primary`。
    private var accent: Color { tint ?? theme.primary }

    /// 创建 Hero 横幅。
    /// - Parameters:
    ///   - icon: SF Symbol 名称,显示在左上角徽标内。
    ///   - accent: 主题强调色(驱动渐变与图标)。默认跟随主题 `primary`。
    ///   - tagline: 一句有感染力的标语。
    ///   - chips: 可选的特性胶囊文案(最多展示 4 个)。
    ///   - metrics: 可选的迷你统计(value/label)。
    public init(
        icon: String,
        accent: Color? = nil,
        tagline: String,
        chips: [String] = [],
        metrics: [AppPluginPosterMetric] = []
    ) {
        self.icon = icon
        self.tint = accent
        self.tagline = tagline
        self.chips = chips
        self.metrics = metrics
    }

    public var body: some View {
        ZStack {
            // 渐变底
            LinearGradient(
                colors: [
                    accent.opacity(0.22),
                    theme.surface,
                    theme.surface.opacity(0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // 左上柔光
            RadialGradient(
                colors: [accent.opacity(0.28), .clear],
                center: .topLeading,
                startRadius: 1,
                endRadius: 240
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 16) {
                    iconBadge
                    taglineBlock
                    Spacer(minLength: 0)
                }

                if !chips.isEmpty {
                    chipsRow
                }

                if !metrics.isEmpty {
                    metricsRow
                }
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.appDivider, lineWidth: 1)
        )
    }

    // MARK: - Subviews

    private var iconBadge: some View {
        Image(systemName: icon)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(
                LinearGradient(colors: [accent, accent.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(accent.opacity(0.25), lineWidth: 1)
                    )
            )
    }

    private var taglineBlock: some View {
        Text(tagline)
            .font(.system(size: 20, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var chipsRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(chips.prefix(4).enumerated()), id: \.offset) { _, chip in
                Text(chip)
                    .font(.appCaptionEmphasized)
                    .foregroundColor(theme.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(theme.appPanelBackground.opacity(0.7))
                    )
                    .overlay(Capsule().strokeBorder(theme.appDivider, lineWidth: 1))
            }
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(metrics.prefix(4).enumerated()), id: \.offset) { _, metric in
                VStack(spacing: 2) {
                    Text(metric.value)
                        .font(.appBodyEmphasized)
                        .foregroundColor(accent)
                        .lineLimit(1)
                    Text(metric.label)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.appPanelBackground.opacity(0.7))
                )
            }
        }
    }
}

#Preview {
    VStack {
        LandingHero(
            icon: "bolt.fill",
            tagline: "让 Mac 在长时间任务中保持唤醒,下载、渲染、演示不再被打断。",
            chips: ["无限模式", "定时模式", "息屏运行"],
            metrics: [
                .init(value: "3", label: "运行模式"),
                .init(value: "0", label: "额外配置")
            ]
        )
    }
    .padding()
    .frame(width: 520)
}
