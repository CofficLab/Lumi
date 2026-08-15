import LumiUI
import SwiftUI

/// 设备信息插件关于视图 —— 以「实时监控 + 历史曲线」为主轴的落地页。
///
/// 复刻自 Lumi DeviceInfoPlugin 的 DeviceInfoAboutView，使用 LumiUI
/// 的 Landing 组件（Hero / Section / FeatureGrid / Inventory）。
public struct DeviceInfoAboutView: View {
    @LumiTheme private var theme

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                capabilitiesSection
                entriesSection
            }
            .padding(22)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "macbook.and.iphone",
            accent: theme.info,
            tagline: "实时洞察你的 Mac：CPU、内存、磁盘、电池与运行时间。",
            chips: ["CPU", "内存", "磁盘", "电池"],
            metrics: [
                .init(value: "4", label: "监控维度"),
                .init(value: "2s", label: "刷新间隔"),
            ]
        )
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: "核心能力", icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "cpu", tint: theme.warning,
                      title: "CPU 监控",
                      description: "实时使用率与核心信息。"),
                .init(icon: "memorychip", tint: theme.success,
                      title: "内存监控",
                      description: "已用/总量与占用率。"),
                .init(icon: "internaldrive", tint: theme.warning,
                      title: "磁盘概览",
                      description: "容量与已用空间一目了然。"),
                .init(icon: "battery.75", tint: theme.primary,
                      title: "电池状态",
                      description: "电量与充电状态。"),
                .init(icon: "timer", tint: theme.info,
                      title: "运行时间",
                      description: "系统持续运行时长。"),
            ])
        }
    }

    // MARK: - 入口

    private var entriesSection: some View {
        LandingSection(title: "在哪里找到它", icon: "checkmark.seal") {
            LandingInventory(tint: theme.info, items: [
                .init(icon: "macwindow",
                      title: "主内容区的设备信息面板"),
                .init(icon: "gearshape",
                      title: "设置 → 设备信息"),
            ])
        }
    }
}
