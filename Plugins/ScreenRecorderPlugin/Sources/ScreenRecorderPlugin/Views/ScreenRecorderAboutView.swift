import LumiUI
import SwiftUI

/// 屏幕录制插件关于视图 —— 以「对话驱动录制」为主轴的落地页。
struct ScreenRecorderAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            capabilitiesSection
            howItWorksSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "record.circle",
            accent: theme.error,
            tagline: L(
                "Record any app's usage flow to a video file in your Downloads folder — driven entirely by chat, with optional audio.",
                "通过对话录制任意 app 的使用流程,可选声音,结束后自动把视频输出到下载目录。"
            ),
            chips: [
                L("Any App", "任意 App"),
                L("Optional Audio", "可选声音"),
                L("Floating Indicator", "置顶指示器"),
                L("Auto Export", "自动导出")
            ],
            metrics: [
                .init(value: "3", label: L("agent tools", "Agent 工具")),
                .init(value: L("Chat", "对话"), label: L("driven by", "驱动方式")),
                .init(value: L("Downloads", "下载目录"), label: L("output to", "输出位置"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities", "核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "record.circle", tint: theme.error,
                      title: L("start_recording", "start_recording"),
                      description: L("Start recording the frontmost or named app, with optional mic/system audio.", "开始录制当前或指定的 app,可选拾音 / 系统声音。")),
                .init(icon: "stop.circle", tint: theme.success,
                      title: L("stop_recording", "stop_recording"),
                      description: L("Stop the session and export the video to Downloads automatically.", "结束会话并自动把视频导出到下载目录。")),
                .init(icon: "list.bullet.rectangle", tint: theme.info,
                      title: L("list_recordable_apps", "list_recordable_apps"),
                      description: L("Ask which apps are currently available to record.", "查询当前可录制的 app 列表。")),
                .init(icon: "pip.remove", tint: theme.warning,
                      title: L("Floating Indicator", "置顶状态指示器"),
                      description: L("A system-level always-on-top panel shows recording state while capturing.", "录制期间用系统级置顶浮层指示器反馈状态。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("How It Works", "工作原理"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("Enable the plugin", "启用插件"), description: L("Turn it on in Plugin Manager (off by default).", "默认关闭,在插件管理中启用。"), icon: "power"),
                .init(title: L("Ask in chat", "对话中发起"), description: L("Say something like: record the current app's usage flow for me.", "例如:帮我录制一下当前 app 的使用流程。"), icon: "bubble.left.and.text.bubble.right"),
                .init(title: L("Stop and export", "停止并导出"), description: L("End the session; the video lands in your Downloads folder.", "结束会话,视频自动保存到下载目录。"), icon: "tray.and.arrow.down")
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ en: String, _ zh: String) -> String {
        ScreenRecorderLocalization.string(en, zh)
    }
}

#Preview {
    ScrollView {
        ScreenRecorderAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
