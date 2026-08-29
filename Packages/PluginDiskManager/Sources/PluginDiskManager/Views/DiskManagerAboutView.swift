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
            tagline: L("See disk usage clearly, find large files, and clean caches and build artifacts to reclaim space."),
            chips: [L("Usage Overview"), L("Large File Scan"), L("Cache Cleanup")],
            metrics: [
                .init(value: "1-tap", label: L("Finder Locate")),
                .init(value: "Multi", label: L("Cleanup Items")),
                .init(value: "Visual", label: L("Directory Tree"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 关键指标

    private var statsSection: some View {
        LandingSection(title: L("Disk Status at a Glance"), icon: "chart.pie") {
            LandingStatStrip(accent: theme.warning, metrics: [
                .init(value: "Total/Used", label: L("Disk Overview")),
                .init(value: "Top N", label: L("Large File Ranking")),
                .init(value: "Tree", label: L("Directory Share")),
                .init(value: "Safe", label: L("Cleanup Strategy"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "chart.pie", tint: theme.warning,
                      title: L("Usage Overview"),
                      description: L("View total capacity, used and available space at a glance.")),
                .init(icon: "doc.fill", tint: theme.info,
                      title: L("Large File Scan"),
                      description: L("Find large files sorted by size for easy cleanup.")),
                .init(icon: "rectangle.3.group", tint: theme.primary,
                      title: L("Directory Analysis"),
                      description: L("View folder usage breakdown with an interactive tree view.")),
                .init(icon: "sparkles", tint: theme.success,
                      title: L("Cache and Build Cleanup"),
                      description: L("Safely clean Xcode DerivedData, simulators, archives and build artifacts.")),
                .init(icon: "folder.badge.gearshape", tint: theme.warning,
                      title: L("Project Cleanup"),
                      description: L("Scan DerivedData, build, CocoaPods caches and other cleanable items.")),
                .init(icon: "magnifyingglass.circle", tint: theme.info,
                      title: L("Finder Integration"),
                      description: L("Locate any scan result in Finder with one click."))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 可清理类别

    private var cleanupSection: some View {
        LandingSection(title: L("Cleanable Categories"), icon: "trash.circle") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "server.rack", title: L("System Caches"), description: L("Temporary files")),
                .init(icon: "hammer", title: "Xcode DerivedData", description: L("Build artifacts")),
                .init(icon: "rectangle.stack.badge.play", title: L("Old Simulators"), description: L("iOS Simulator")),
                .init(icon: "archivebox", title: L("Archives"), description: L("Archives")),
                .init(icon: "shippingbox", title: "CocoaPods", description: L("Cache")),
                .init(icon: "folder.fill.badge.plus", title: "build", description: L("Build directory"))
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
