import LumiUI
import SwiftUI

/// 网络管理插件关于视图 —— 以「实时仪表盘」为主轴的落地页。
struct NetworkManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            statsSection
            capabilitiesSection
            howItWorksSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "wifi",
            accent: theme.success,
            tagline: L("实时监控上传下载速度、流量统计与进程占用,菜单栏即可一览网络状态。"),
            chips: [L("实时测速"), L("流量统计"), L("进程监控"), L("菜单栏")],
            metrics: [
                .init(value: "↑↓", label: L("实时速率")),
                .init(value: "图表", label: L("历史流量")),
                .init(value: "进程", label: L("按应用归集"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 实时状态

    private var statsSection: some View {
        LandingSection(title: L("一眼掌握的网络状态"), icon: "chart.bar.fill") {
            LandingStatStrip(accent: theme.success, metrics: [
                .init(value: "↑↓", label: L("上传 / 下载")),
                .init(value: "GB", label: L("累计流量")),
                .init(value: "Top", label: L("耗流进程")),
                .init(value: "菜单栏", label: L("常驻显示"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "speedometer", tint: theme.success,
                      title: L("实时测速"),
                      description: L("实时跟踪上传与下载速度,附带详细统计。")),
                .init(icon: "chart.xyaxis.line", tint: theme.info,
                      title: L("流量统计"),
                      description: L("按时间累计数据用量,以历史图表呈现。")),
                .init(icon: "app.dashed", tint: theme.warning,
                      title: L("进程监控"),
                      description: L("查看哪些应用正在占用网络带宽。")),
                .init(icon: "menubar.rectangle", tint: theme.primary,
                      title: L("菜单栏集成"),
                      description: L("从菜单栏快速查看网络状态。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("工作原理"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("采集数据"), description: L("读取网卡的上传与下载流量。"), icon: "antenna.radiowaves.left.and.right"),
                .init(title: L("按进程归集"), description: L("把带宽占用归到对应应用。")),
                .init(title: L("绘制图表"), description: L("生成实时曲线与历史统计。")),
                .init(title: L("菜单栏展示"), description: L("常驻菜单栏,随时一览。"))
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
        NetworkManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
