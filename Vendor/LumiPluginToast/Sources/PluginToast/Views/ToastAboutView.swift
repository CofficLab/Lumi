import LumiUI
import SwiftUI

/// Toast 插件关于视图。
///
/// 为 Lumi 系列应用提供统一的瞬时通知能力：轻量的 toast 出现在窗口顶部，
/// 自动消失，高频消息以「替换式节流」避免堆叠。
struct ToastAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            LandingHero(
                icon: "bell.badge.fill",
                accent: theme.warning,
                tagline: L("Lightweight notifications that never get in your way."),
                chips: [L("Auto-dismiss"), L("Non-blocking"), L("Throttled")],
                metrics: [
                    .init(value: "3s", label: L("default duration")),
                    .init(value: "Top", label: L("display position"))
                ]
            )
            .landingAppear()

            LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
                LandingFeatureGrid(items: [
                    .init(icon: "timer", tint: theme.warning,
                          title: L("Auto-Dismiss"),
                          description: L("Each toast fades away on its own after a few seconds.")),
                    .init(icon: "rectangle.compress.vertical", tint: theme.info,
                          title: L("Replacement Throttle"),
                          description: L("Rapid-fire messages refresh the current toast instead of stacking.")),
                    .init(icon: "arrow.up.to.line", tint: theme.success,
                          title: L("Top Overlay"),
                          description: L("Toasts render at the top of the window, above all content."))
                ])
            }
            .landingAppear(delay: 0.05)

            LandingSection(title: L("How It Works"), icon: "arrow.triangle.branch.and.merge") {
                LandingStepFlow(steps: [
                    .init(title: L("Show"), description: L("Any plugin calls the toast service with a message and style."), icon: "bell.badge"),
                    .init(title: L("Display"), description: L("The root overlay renders the toast at the top of the window."), icon: "rectangle.topthird.inset.filled"),
                    .init(title: L("Dismiss"), description: L("The timer clears it automatically — or a newer toast takes its place."), icon: "timer")
                ])
            }
            .landingAppear(delay: 0.1)
        }
    }

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        ToastAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
