import KernelLumi
import LumiUI
import SwiftUI

/// 白噪音插件关于视图 —— 以「实时生成 + 三轨混合」为主轴的落地页。
struct WhiteNoiseAboutView: View {
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
            icon: "speaker.wave.2.fill",
            accent: theme.primary,
            tagline: L(
                en: "Real-time generated white, pink and brown noise for focus and sleep — no audio files, seamless loops, mixable tracks.",
                zh: "实时生成白噪音、粉噪音、棕噪音,助力专注与助眠:无音频文件、真正无缝循环、多轨自由混合。"
            ),
            chips: [
                L(en: "White Noise", zh: "白噪音"),
                L(en: "Pink Noise", zh: "粉噪音"),
                L(en: "Brown Noise", zh: "棕噪音"),
                L(en: "Sleep Timer", zh: "睡眠定时")
            ],
            metrics: [
                .init(value: "3", label: L(en: "noise tracks", zh: "噪声音轨")),
                .init(value: L(en: "Mix", zh: "混音"), label: L(en: "independent volumes", zh: "独立音量")),
                .init(value: "60min", label: L(en: "sleep timer", zh: "睡眠定时"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L(en: "Core Capabilities", zh: "核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "waveform", tint: theme.primary,
                      title: L(en: "Real-time Synthesis", zh: "实时算法生成"),
                      description: L(en: "Frame-by-frame generation via AVAudioEngine, no audio files, truly seamless.", zh: "基于 AVAudioEngine 逐帧生成,无音频文件、真正无缝循环。")),
                .init(icon: "slider.horizontal.3", tint: theme.info,
                      title: L(en: "Three-track Mixer", zh: "三轨混合"),
                      description: L(en: "Toggle white, pink and brown noise independently and blend with per-track volume.", zh: "白 / 粉 / 棕噪声独立开关、各自调节音量,混合输出。")),
                .init(icon: "timer", tint: theme.success,
                      title: L(en: "Sleep Timer", zh: "睡眠定时器"),
                      description: L(en: "Auto-stop after 15 / 30 / 60 minutes with a countdown.", zh: "15 / 30 / 60 分钟后自动停止,带倒计时。")),
                .init(icon: "music.note.list", tint: theme.warning,
                      title: L(en: "Plays Along Your Music", zh: "与其它音频共存"),
                      description: L(en: "Mixes with other apps' audio without interrupting your music.", zh: "以混音模式运行,不打断你正在听的音乐。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L(en: "How It Works", zh: "工作原理"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L(en: "Enable the plugin", zh: "启用插件"), description: L(en: "Turn it on in Plugin Manager (off by default).", zh: "默认关闭,在插件管理中启用。"), icon: "power"),
                .init(title: L(en: "Open the sidebar view", zh: "打开侧边栏视图"), description: L(en: "The White Noise container appears in the ActivityBar.", zh: "侧边栏 ActivityBar 出现白噪音容器。"), icon: "sidebar.left"),
                .init(title: L(en: "Mix your noise", zh: "混合噪声"), description: L(en: "Toggle tracks, tweak volumes and set a sleep timer.", zh: "开关音轨、调节音量、按需设置睡眠定时。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(en: String, zh: String) -> String {
        LumiLanguagePreference.current.localized(en: en, zh: zh)
    }
}

#Preview {
    ScrollView {
        WhiteNoiseAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
