import LumiUI
import SwiftUI

/// 空闲时间插件关于视图 —— 以「能力网格 + 适用场景」为主轴的落地页。
struct IdleTimeAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            useCasesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "clock.badge.xmark",
            accent: theme.warning,
            tagline: L("记录你一整天的空闲与活动节律:可视化热条、空闲提醒、会话统计,看清时间去哪了。"),
            chips: [L("空闲追踪"), L("活动可视化"), L("提醒"), L("会话分析")],
            metrics: [
                .init(value: "全天", label: L("活动追踪")),
                .init(value: "可配置", label: L("提醒阈值")),
                .init(value: "趋势", label: L("会话统计"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "clock.badge.xmark", tint: theme.warning,
                      title: L("空闲时间追踪"),
                      description: L("监控全天电脑空闲时间与不活动模式。")),
                .init(icon: "rectangle.split.3x1", tint: theme.info,
                      title: L("活动可视化"),
                      description: L("以热条展示你何时活跃、何时空闲。")),
                .init(icon: "bell.badge", tint: theme.error,
                      title: L("空闲提醒"),
                      description: L("空闲达到设定时长后收到通知。")),
                .init(icon: "chart.bar.fill", tint: theme.success,
                      title: L("会话分析"),
                      description: L("结合空闲统计剖析工作会话与趋势。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 适用场景

    private var useCasesSection: some View {
        LandingSection(title: L("适用场景"), icon: "sparkles") {
            LandingFeatureGrid(items: [
                .init(icon: "timer", tint: theme.primary,
                      title: L("专注计时"), description: L("结合空闲识别真实的专注时长。")),
                .init(icon: "figure.stand", tint: theme.success,
                      title: L("健康提醒"), description: L("久坐空闲时提醒你起身活动。")),
                .init(icon: "calendar.badge.clock", tint: theme.info,
                      title: L("作息分析"), description: L("看清一天的活跃与休息节律。")),
                .init(icon: "chart.xyaxis.line", tint: theme.warning,
                      title: L("效率复盘"), description: L("用会话趋势回顾长期效率。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        IdleTimeAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
