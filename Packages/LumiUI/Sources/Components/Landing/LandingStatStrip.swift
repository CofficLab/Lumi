import SwiftUI

/// 大数字 + 标签的统计条。
///
/// 将若干 `AppPluginPosterMetric`(value/label)平铺成一组胶囊化的小卡片,
/// 用于在落地页中突出关键数字(模式数、快捷键数、支持格式数等)。
public struct LandingStatStrip: View {
    @LumiTheme private var theme

    private let metrics: [AppPluginPosterMetric]
    private let tint: Color?

    /// 强调色。默认跟随主题 `primary`。
    private var accent: Color { tint ?? theme.primary }

    public init(metrics: [AppPluginPosterMetric], accent: Color? = nil) {
        self.metrics = metrics
        self.tint = accent
    }

    public var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), spacing: 10)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                VStack(spacing: 3) {
                    Text(metric.value)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(metric.label)
                        .font(.appMicro)
                        .foregroundColor(theme.textTertiary)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.textSecondary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.appSubtleBorder, lineWidth: 1)
                )
            }
        }
    }
}

#Preview {
    LandingStatStrip(metrics: [
        .init(value: "3", label: "运行模式"),
        .init(value: "12", label: "Agent 工具"),
        .init(value: "∞", label: "时长上限")
    ])
    .padding()
    .frame(width: 420)
}
