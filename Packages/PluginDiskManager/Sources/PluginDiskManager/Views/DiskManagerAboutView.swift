import LumiUI
import SwiftUI

/// 磁盘管理插件关于视图 —— 以「仪表盘」式概览为主轴的落地页。
struct DiskManagerAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            statsSection
            capabilitiesSection
            cleanupSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "internaldrive",
            accent: theme.warning,
            tagline: L("看清磁盘占用、揪出大文件、一键清理缓存与构建产物,把空间找回来。"),
            chips: [L("用量概览"), L("大文件扫描"), L("缓存清理")],
            metrics: [
                .init(value: "1键", label: L("Finder 定位")),
                .init(value: "多类", label: L("清理项")),
                .init(value: "可视", label: L("目录树"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 关键指标

    private var statsSection: some View {
        LandingSection(title: L("一眼掌握的磁盘状态"), icon: "chart.pie") {
            LandingStatStrip(accent: theme.warning, metrics: [
                .init(value: "总/已用", label: L("磁盘概览")),
                .init(value: "Top N", label: L("大文件排序")),
                .init(value: "树状", label: L("目录占比")),
                .init(value: "安全", label: L("清理策略"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "chart.pie", tint: theme.warning,
                      title: L("用量概览"),
                      description: L("一眼查看总容量、已用与可用,掌握空间消耗趋势。")),
                .init(icon: "doc.fill", tint: theme.info,
                      title: L("大文件扫描"),
                      description: L("按大小排序找出占地方的文件,便于清理。")),
                .init(icon: "rectangle.3.group", tint: theme.primary,
                      title: L("目录分析"),
                      description: L("以可交互的树状视图查看各文件夹的占用占比。")),
                .init(icon: "sparkles", tint: theme.success,
                      title: L("缓存与构建清理"),
                      description: L("安全清理 Xcode DerivedData、模拟器、归档等构建产物。")),
                .init(icon: "folder.badge.gearshape", tint: theme.warning,
                      title: L("项目清理"),
                      description: L("扫描项目里的 DerivedData、build、CocoaPods 缓存等可删项。")),
                .init(icon: "magnifyingglass.circle", tint: theme.info,
                      title: L("Finder 集成"),
                      description: L("对任意扫描结果一键在 Finder 中定位。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 可清理类别

    private var cleanupSection: some View {
        LandingSection(title: L("可清理的类别"), icon: "trash.circle") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "server.rack", title: L("系统缓存"), description: L("临时文件")),
                .init(icon: "hammer", title: "Xcode DerivedData", description: L("构建产物")),
                .init(icon: "rectangle.stack.badge.play", title: L("旧模拟器"), description: L("iOS Simulator")),
                .init(icon: "archivebox", title: L("归档"), description: L("Archives")),
                .init(icon: "shippingbox", title: "CocoaPods", description: L("缓存")),
                .init(icon: "folder.fill.badge.plus", title: "build", description: L("构建目录"))
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
        DiskManagerAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
