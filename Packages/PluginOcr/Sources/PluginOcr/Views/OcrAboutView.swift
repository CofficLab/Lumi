import LumiUI
import SwiftUI

/// OCR 插件关于视图 —— 以「端侧识别 + 隐私」为主轴的落地页。
struct OcrAboutView: View {
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
            icon: "text.viewfinder",
            accent: theme.success,
            tagline: L(
                "Recognize text in local images with the on-device macOS Vision framework — fully offline, no third-party APIs, no network requests.",
                "使用 macOS Vision 识别本地图片中的文字:完全离线、不调用第三方 API、不产生网络请求。"
            ),
            chips: [
                L("Vision", "Vision 框架"),
                L("On-device", "端侧推理"),
                L("Offline", "完全离线"),
                L("Multi-language", "多语言")
            ],
            metrics: [
                .init(value: "1", label: L("agent tool", "Agent 工具")),
                .init(value: "0", label: L("network requests", "网络请求")),
                .init(value: "5+", label: L("image formats", "图片格式"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("Core Capabilities", "核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "text.recognition", tint: theme.success,
                      title: L("ocr_image Agent Tool", "ocr_image Agent 工具"),
                      description: L("Ask the agent in chat to extract text from a local image file.", "在对话中让 Agent 识别本地图片文件中的文字。")),
                .init(icon: "lock.shield", tint: theme.primary,
                      title: L("Private by Design", "隐私友好"),
                      description: L("Images never leave your Mac; recognition runs entirely on-device.", "图片永不出本机,识别全部在本机完成。")),
                .init(icon: "globe", tint: theme.info,
                      title: L("Multi-language", "多语言识别"),
                      description: L("Chinese and English by default; hint languages like ja / ko / fr / de via the language parameter.", "默认简体中文 + 英文,可通过 language 参数指定 ja / ko / fr / de 等。")),
                .init(icon: "photo.stack", tint: theme.warning,
                      title: L("Common Formats", "常见格式"),
                      description: L("Supports PNG, JPEG, HEIC, TIFF, GIF and more.", "支持 PNG、JPEG、HEIC、TIFF、GIF 等常见格式。"))
            ])
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 工作原理

    private var howItWorksSection: some View {
        LandingSection(title: L("How It Works", "工作原理"), icon: "gearshape.2") {
            LandingStepFlow(steps: [
                .init(title: L("Enable the plugin", "启用插件"), description: L("Turn it on in Plugin Manager (off by default).", "默认关闭,在插件管理中启用。"), icon: "power"),
                .init(title: L("Point the agent at an image", "让 Agent 找到图片"), description: L("Give a local image path in the conversation.", "在对话中提供本地图片路径。"), icon: "photo"),
                .init(title: L("Get the text back", "取回文字"), description: L("Recognized text is returned straight into the chat.", "识别出的文字直接送回对话。"), icon: "text.quote")
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - Localization

    private func L(_ en: String, _ zh: String) -> String {
        OcrLocalization.string(en, zh)
    }
}

#Preview {
    ScrollView {
        OcrAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
