import LumiUI
import SwiftUI

// MARK: - Manual View

/// 白噪音使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
/// 本插件暂无本地化基础设施,手册文案暂以英文硬编码。
struct WhiteNoiseManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: "White Noise",
                subtitle: "User Manual"
            )

            ManualSectionHeader(number: 1, title: "Overview")
            Text(LumiPluginLocalization.string("This manual covers the interface and basic operations of White Noise: playing noise tracks, adjusting volumes, and setting the sleep timer.", bundle: .module))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: "Interface")
            ManualBulletList(items: [
                .init("Master card: shows the playing status, the Play / Stop button, and the Master Volume slider."),
                .init("Track list: White, Pink, and Brown noise rows, each with an on/off switch and a volume slider."),
                .init("Sleep Timer card: shows the remaining countdown and a duration picker."),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: "Basic Operations")
            ManualStepList(items: [
                .init("Open the White Noise tab in the sidebar."),
                .init("Click Play to start playback."),
                .init("Turn on the noise tracks you need and adjust their volumes."),
                .init("Use the Master Volume slider to adjust the overall volume."),
                .init("Set a duration in the Sleep Timer to stop playback automatically."),
            ])

            ManualSectionHeader(number: 4, title: "Notes")
            ManualBulletList(items: [
                .init("When the sleep timer reaches zero, playback stops automatically."),
                .init("Volume and sleep-timer controls are available during playback."),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: "Figure 1: Interface layout") {
            VStack(spacing: 12) {
                // ① 主控卡片
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.textSecondary)
                        VStack(alignment: .leading, spacing: 4) {
                            lineMock(width: 52)
                            lineMock(width: 28)
                        }
                        Spacer(minLength: 0)
                    }

                    buttonPill("Play")

                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.1.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textSecondary)
                        sliderMock()
                        lineMock(width: 18)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider)
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 音轨列表
                VStack(spacing: 7) {
                    trackRowMock()
                    trackRowMock()
                    trackRowMock()
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, "Master card")
                    ManualFigureLegendItem(2, "Track list")
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 音轨行示意:图标 + 两根文字线 + 开关 + 滑块。
    private func trackRowMock() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 3) {
                    lineMock(width: 40)
                    lineMock(width: 58)
                }

                Spacer(minLength: 0)

                toggleMock(on: true)
            }

            HStack(spacing: 8) {
                sliderMock()
                lineMock(width: 18)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    /// 开关示意:开启状态的胶囊滑块。
    private func toggleMock(on: Bool) -> some View {
        ZStack(alignment: on ? .trailing : .leading) {
            Capsule()
                .fill(on ? theme.primary.opacity(0.6) : Color.primary.opacity(0.15))
                .frame(width: 28, height: 16)
            Circle()
                .fill(.white)
                .frame(width: 12, height: 12)
                .shadow(radius: 1)
                .padding(2)
        }
    }

    /// 滑块示意:轨道 + 圆形滑块。
    private func sliderMock() -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(height: 4)
            Circle()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 10, height: 10)
                .padding(.leading, 44)
        }
        .frame(maxWidth: .infinity)
    }

    /// 按钮示意。
    private func buttonPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.primary.opacity(0.15))
            )
    }

    /// 示意图中的占位文字线。
    private func lineMock(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.primary.opacity(0.14))
            .frame(width: width, height: 3)
    }
}

#Preview {
    ScrollView {
        WhiteNoiseManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
