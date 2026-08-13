import LumiUI
import SwiftUI

/// 活动热力图插件关于视图 —— 以「可视化 + 数据洞察」为主轴的落地页。
struct ActivityHeatmapAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            spotlightSection
            capabilitiesSection
            insightsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "calendar",
            accent: theme.success,
            tagline: L("把你的对话活动可视化为 GitHub 风格的热力图,颜色深浅反映每日消息量,一眼看全年。"),
            chips: [L("热力图"), L("Token 追踪"), L("统计看板"), L("本地缓存")],
            metrics: [
                .init(value: "365", label: L("天视图")),
                .init(value: "逐日", label: L("消息统计")),
                .init(value: "本地", label: L("即时加载"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 签名特性

    private var spotlightSection: some View {
        LandingSpotlight(
            icon: "square.grid.3x3.fill",
            tint: theme.success,
            title: L("GitHub 风格的活动热力图"),
            message: L("以日历热力图呈现每日对话量,颜色越深代表越活跃,长期趋势一目了然。")
        ) {
            HStack(spacing: 6) {
                AppTag(L("全年"), style: .subtle)
                AppTag(L("逐日"), style: .subtle)
                AppTag(L("颜色映射"), style: .subtle)
            }
            .padding(.top, 4)
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "calendar", tint: theme.success,
                      title: L("活动热力图"),
                      description: L("用热力图可视化对话活动,颜色反映每日消息量。")),
                .init(icon: "chart.line.uptrend.xyaxis", tint: theme.info,
                      title: L("Token 消耗追踪"),
                      description: L("交互式折线图监控每日 Token 用量,发现高消耗日。")),
                .init(icon: "chart.bar.fill", tint: theme.warning,
                      title: L("统计看板"),
                      description: L("总消息数、活跃天、当前 / 最长连续天数、工作日分布等。")),
                .init(icon: "internaldrive", tint: theme.primary,
                      title: L("高效缓存"),
                      description: L("历史数据本地缓存即时加载,今日数据实时获取。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 统计洞察

    private var insightsSection: some View {
        LandingSection(title: L("一眼看到的洞察"), icon: "chart.pie") {
            LandingStatStrip(accent: theme.success, metrics: [
                .init(value: "总消息", label: L("累计计数")),
                .init(value: "活跃天", label: L("有活动的天")),
                .init(value: "连续", label: L("当前 / 最长 streak")),
                .init(value: "工作日", label: L("分布占比"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        ActivityHeatmapAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
