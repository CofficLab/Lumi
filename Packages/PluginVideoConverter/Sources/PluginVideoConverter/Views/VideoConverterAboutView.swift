import LumiUI
import SwiftUI

/// 视频转换插件关于视图 —— 以「输入 → 转码 → 输出」管线为主轴的落地页。
struct VideoConverterAboutView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            hero
            pipelineSection
            capabilitiesSection
            formatsSection
        }
    }

    // MARK: - Hero

    private var hero: some View {
        LandingHero(
            icon: "film",
            accent: theme.warning,
            tagline: L("基于 FFmpeg 的视频转换:在常见格式间自由互转,支持批量队列与画质调节。"),
            chips: [L("多格式"), L("FFmpeg 引擎"), L("批量队列")],
            metrics: [
                .init(value: "5+", label: L("常用格式")),
                .init(value: "批量", label: L("队列处理")),
                .init(value: "FFmpeg", label: L("内核"))
            ]
        )
        .landingAppear()
    }

    // MARK: - 管线

    private var pipelineSection: some View {
        LandingSection(title: L("转换流程"), icon: "arrow.triangle.swap") {
            LandingPipeline(
                tint: theme.warning,
                stages: [
                    .init(icon: "film.stack", title: L("导入视频"), subtitle: L("拖入或选择文件")),
                    .init(icon: "gearshape.2", title: L("FFmpeg 转码"), subtitle: L("可选画质 / 分辨率 / 编码")),
                    .init(icon: "checkmark.seal", title: L("输出文件"), subtitle: L("MP4 / MOV / GIF / 音频"))
                ]
            )
        }
        .landingAppear(delay: 0.05)
    }

    // MARK: - 核心能力

    private var capabilitiesSection: some View {
        LandingSection(title: L("核心能力"), icon: "square.grid.2x2") {
            LandingFeatureGrid(items: [
                .init(icon: "arrow.triangle.2.circlepath", tint: theme.warning,
                      title: L("格式转换"),
                      description: L("在 MP4、MOV、AVI、MKV 等常见格式之间互转。")),
                .init(icon: "slider.horizontal.3", tint: theme.info,
                      title: L("画质设置"),
                      description: L("调节视频画质、分辨率与编码,兼顾体积与清晰度。")),
                .init(icon: "bolt.fill", tint: theme.success,
                      title: L("FFmpeg 驱动"),
                      description: L("依托 FFmpeg,转换快速且可靠。")),
                .init(icon: "list.bullet.rectangle", tint: theme.primary,
                      title: L("批量处理"),
                      description: L("把多个文件加入队列,逐个转换并跟踪进度。"))
            ])
        }
        .landingAppear(delay: 0.1)
    }

    // MARK: - 支持格式

    private var formatsSection: some View {
        LandingSection(title: L("支持的格式"), icon: "shippingbox") {
            LandingInventory(tint: theme.warning, items: [
                .init(icon: "rectangle.stack", title: "MP4 / MOV", description: L("通用视频")),
                .init(icon: "rectangle.stack", title: "AVI / MKV", description: L("容器格式")),
                .init(icon: "gift", title: "GIF", description: L("动图导出")),
                .init(icon: "waveform", title: L("音频提取"), description: "MP3 / AAC")
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
        VideoConverterAboutView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
