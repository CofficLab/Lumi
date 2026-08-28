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
            tagline: L("Real-time generated white, pink and brown noise for focus and sleep — no audio files, seamless loops, mixable tracks."),
            chips: [
                L("White Noise"),
                L("Pink Noise"),
                L("Brown Noise"),
                L("Sleep Timer")
            ],
            metrics: [
                .init(value: "3", label: L("noise tracks")),
                .init(value: L("Mix"), label: L("independent volumes")),
                .init(value: "60min", label: L("sleep timer"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "waveform", tint: theme.primary,
                      title: L("Real-time Synthesis"),
                      description: L("Frame-by-frame generation via AVAudioEngine, no audio files, truly seamless.")),
                .init(icon: "slider.horizontal.3", tint: theme.info,
                      title: L("Three-track Mixer"),
                      description: L("Toggle white, pink and brown noise independently and blend with per-track volume.")),
                .init(icon: "timer", tint: theme.success,
                      title: L("Sleep Timer"),
                      description: L("Auto-stop after 15 / 30 / 60 minutes with a countdown.")),
                .init(icon: "music.note.list", tint: theme.warning,
                      title: L("Plays Along Your Music"),
                      description: L("Mixes with other apps' audio without interrupting your music."))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("How It Works"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("Enable the plugin"), description: L("Turn it on in Plugin Manager (off by default)."), icon: "power"),
                .init(title: L("Open the sidebar view"), description: L("The White Noise container appears in the ActivityBar."), icon: "sidebar.left"),
                .init(title: L("Mix your noise"), description: L("Toggle tracks, tweak volumes and set a sleep timer."))
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
        WhiteNoiseAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
