import LumiUI
import SwiftUI

/// 防休眠插件关于视图 —— 以产品落地页的形式介绍功能。
struct CaffeinateAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            modesSection
            howItWorksSection
            useCasesSection
            requirementsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "bolt.fill",
            tagline: L("让 Mac 在长时间任务中保持唤醒——下载、渲染、演示都不再被打断。"),
            chips: [L("无限模式"), L("定时模式"), L("息屏运行")],
            metrics: [
                .init(value: "3", label: L("运行模式")),
                .init(value: "1", label: L("一键切换")),
                .init(value: "0", label: L("额外配置"))
            ]
        )
        .landingAppear(delay: 0)
    }

    // MARK: - 运行模式

    private var modesSection: some View {
        LandingSection(title: L("三种运行模式"), icon: "switch.2", subtitle: L("按场景选择最适合的唤醒方式")) {
            LandingFeatureGrid(items: [
                .init(icon: "infinity", tint: theme.primary,
                      title: L("无限模式"),
                      description: L("一直保持唤醒,直到你手动关闭。适合不确定时长的长任务。")),
                .init(icon: "timer", tint: theme.info,
                      title: L("定时模式"),
                      description: L("设定几分钟到几小时,到点自动解除唤醒。")),
                .init(icon: "moon.zzz", tint: theme.warning,
                      title: L("息屏运行"),
                      description: L("系统保持唤醒的同时关闭屏幕,兼顾任务与省电。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("工作原理"), icon: "gearshape.2", subtitle: L("底层基于系统电源断言,安全且无副作用")) {
            LandingStepFlow(steps: [
                .init(title: L("创建电源断言"), description: L("通过 IOKit 向系统注册 power assertion,阻止进入睡眠。"), icon: "bolt.fill"),
                .init(title: L("运行你的任务"), description: L("下载、编译、渲染或演示,系统始终保持唤醒。")),
                .init(title: L("可选关闭屏幕"), description: L("息屏模式下显示休眠,但系统继续运行。")),
                .init(title: L("自动收尾"), description: L("定时模式到点自动释放断言;无限模式由你手动解除。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 常见场景

    private var useCasesSection: some View {
        LandingSection(title: L("常见场景"), icon: "sparkles", subtitle: L("任何时候你都不希望 Mac 突然睡去")) {
            LandingFeatureGrid(items: [
                .init(icon: "arrow.down.circle", tint: theme.info,
                      title: L("大文件下载"), description: L("下载期间保持唤醒,避免中断重试。")),
                .init(icon: "video.fill", tint: theme.warning,
                      title: L("视频处理"), description: L("编码、渲染耗时漫长,全程不掉线。")),
                .init(icon: "server.rack", tint: theme.success,
                      title: L("后台服务"), description: L("运行本地服务或长任务不被打断。")),
                .init(icon: "rectangle.on.rectangle.angled", tint: theme.primary,
                      title: L("演示与会议"), description: L("投屏或演示时屏幕不熄灭。"))
            ])
        }
        .landingAppear(delay: 0.15)
    }

    // MARK: - 要求

    private var requirementsSection: some View {
        LandingSection(title: L("环境要求"), icon: "checkmark.seal") {
            AppCard(style: .subtle, cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    requirementRow(L("macOS 14.0 或更高版本"))
                    requirementRow(L("系统电源管理权限(无需额外授权)"))
                    requirementRow(L("无需安装任何附加组件"))
                }
            }
        }
        .landingAppear(delay: 0.2)
    }

    private func requirementRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(theme.success)
            Text(text)
                .font(.appCaption)
                .foregroundColor(theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Localization

    private func L(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: .module)
    }
}

#Preview {
    ScrollView {
        CaffeinateAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
