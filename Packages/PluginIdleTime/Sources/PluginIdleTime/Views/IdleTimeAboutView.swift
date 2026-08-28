import LumiUI
import SwiftUI

/// 空闲时间插件关于视图 —— 以「能力网格 + 适用场景」为主轴的落地页。
///
/// 由旧版 `Plugins/IdleTimePlugin/Sources/Views/IdleTimeAboutView.swift` 迁移而来。
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
            tagline: L("Track your daily activity rhythm: visualize rest windows, idle reminders and session stats to see where time goes."),
            chips: [L("Idle tracking"), L("Activity heatmap"), L("Rest windows")],
            metrics: [
                .init(value: "24h", label: L("Activity tracking")),
                .init(value: "Auto", label: L("Rest detection")),
                .init(value: "Trend", label: L("Session stats"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "clock.badge.xmark", tint: theme.warning,
                      title: L("Idle Time Tracking"),
                      description: L("Monitor daily computer idle time and inactivity patterns.")),
                .init(icon: "rectangle.split.3x1", tint: theme.info,
                      title: L("Activity Visualization"),
                      description: L("See when you are active and idle with a 24-hour heat strip.")),
                .init(icon: "bell.badge", tint: theme.error,
                      title: L("Rest Window Detection"),
                      description: L("Infer your recurring rest windows from activity history.")),
                .init(icon: "chart.bar.fill", tint: theme.success,
                      title: L("Session Analysis"),
                      description: L("Review work sessions and trends over time."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 适用场景

    private var useCasesSection: some View {
        LandingSection(title: L("Use Cases"), icon: "sparkles") {
            LandingFeatureGrid(items: [
                .init(icon: "timer", tint: theme.primary,
                      title: L("Focus Timing"), description: L("Recognize real focus sessions around idle gaps.")),
                .init(icon: "figure.stand", tint: theme.success,
                      title: L("Wellness"), description: L("Notice long idle stretches and take breaks.")),
                .init(icon: "calendar.badge.clock", tint: theme.info,
                      title: L("Rhythm Analysis"), description: L("See your daily active and rest rhythm.")),
                .init(icon: "chart.xyaxis.line", tint: theme.warning,
                      title: L("Efficiency Review"), description: L("Review long-term efficiency from session trends."))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}
