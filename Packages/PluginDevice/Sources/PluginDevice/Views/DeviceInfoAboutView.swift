import LumiUI
import SwiftUI

/// 设备信息插件关于视图 —— 以「实时监控 + 历史曲线」为主轴的落地页。
struct DeviceInfoAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            entriesSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "macbook.and.iphone",
            accent: theme.info,
            tagline: L("Real-time insight into your Mac: CPU, GPU, memory, battery, storage and top processes, with menu bar charts and history graphs."),
            chips: [L("CPU"), L("GPU"), L("Memory"), L("Battery"), L("Storage")],
            metrics: [
                .init(value: "5", label: L("monitor dimensions")),
                .init(value: L("Menu bar"), label: L("live charts")),
                .init(value: L("History"), label: L("trend graphs"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "cpu", tint: theme.warning,
                      title: L("CPU Monitor"),
                      description: L("Per-core usage, frequency and load history.")),
                .init(icon: "gpu", tint: theme.info,
                      title: L("GPU Monitor"),
                      description: L("GPU utilization with trend history.")),
                .init(icon: "memorychip", tint: theme.success,
                      title: L("Memory Monitor"),
                      description: L("Usage, pressure and swap history.")),
                .init(icon: "battery.75", tint: theme.primary,
                      title: L("Battery Status"),
                      description: L("Charge level, power source and cycle history.")),
                .init(icon: "internaldrive", tint: theme.warning,
                      title: L("Storage Overview"),
                      description: L("Disk capacity and free space at a glance.")),
                .init(icon: "square.list", tint: theme.info,
                      title: L("Top Processes"),
                      description: L("Spot the heaviest CPU and memory consumers."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: L("Where to Find It"), icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "macbook.and.iphone",
                      title: L("Device dashboard in the sidebar")),
                .init(icon: "menubar.rectangle",
                      title: L("CPU & memory charts in the menu bar")),
                .init(icon: "gearshape",
                      title: L("Settings → Device Info"))
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
        DeviceInfoAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
