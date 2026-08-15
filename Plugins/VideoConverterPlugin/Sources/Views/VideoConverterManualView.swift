import LumiUI
import SwiftUI

// MARK: - Manual View

/// 视频转换器使用手册 —— 模拟纸质说明书的章节式文档:
/// 编号章节、编号步骤、条目列表与线框示意图,克制严谨,不含宣传性内容。
/// 通过 `pluginManualView` 暴露,在 设置 → 通用 → 新手引导 → 说明书 中阅读。
struct VideoConverterManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Video Converter"),
                subtitle: L("User Manual")
            )

            ManualSectionHeader(number: 1, title: L("Overview"))
            Text(L("This manual covers the interface and basic operations of Video Converter: selecting video files, choosing an output format, and converting them."))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Interface"))
            ManualBulletList(items: [
                .init(L("Drop zone: drag a video file onto it, or click to browse; the selected file shows its name, size, and a Clear button.")),
                .init(L("Settings card: the Output Format picker (MP4, MOV, MKV, AVI, WebM, GIF) and the Convert button.")),
                .init(L("During conversion, a progress bar with the percentage and a Cancel button is shown.")),
                .init(L("The conversion log below records each operation.")),
            ])
            interfaceFigure

            ManualSectionHeader(number: 3, title: L("Basic Operations"))
            ManualStepList(items: [
                .init(L("Open the Video Converter tab in the sidebar.")),
                .init(L("Drag a video file into the drop zone, or click to browse and select one.")),
                .init(L("Choose the output format.")),
                .init(L("Click Convert and wait for the progress to finish, or click Cancel to abort.")),
                .init(L("Check the conversion log for the result.")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes"))
            ManualBulletList(items: [
                .init(L("Conversion time depends on the length and size of the video.")),
                .init(L("GIF output is best suited for short clips.")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    // MARK: - 图 1 界面布局

    private var interfaceFigure: some View {
        ManualFigure(caption: L("Figure 1: Interface layout")) {
            VStack(spacing: 12) {
                // ① 拖放区
                VStack(spacing: 7) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.textSecondary)
                    lineMock(width: 84)
                    lineMock(width: 44)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(theme.appDivider, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                )
                .overlay(alignment: .topLeading) { ManualFigureMarker(1).padding(-7) }

                // ② 格式选择 + 转换按钮
                HStack(spacing: 10) {
                    segmentedMock()
                    Spacer(minLength: 0)
                    buttonPill(L("Convert"))
                }
                .overlay(alignment: .topLeading) { ManualFigureMarker(2).padding(-7) }

                HStack(spacing: 16) {
                    ManualFigureLegendItem(1, L("Drop zone"))
                    ManualFigureLegendItem(2, L("Format picker and Convert button"))
                }
            }
        }
    }

    // MARK: - 示意简笔元素

    /// 输出格式分段控件示意。
    private func segmentedMock() -> some View {
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(i == 0 ? Color.primary.opacity(0.12) : Color.clear)
                    .frame(width: 30, height: 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.appDivider)
        )
    }

    /// 转换按钮示意。
    private func buttonPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(theme.textPrimary)
            .padding(.horizontal, 12)
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

    // MARK: - Localization

    private func L(_ key: String) -> String {
        VideoConverterLocalization.string(key)
    }
}

#Preview {
    ScrollView {
        VideoConverterManualView()
            .padding(22)
    }
    .frame(width: 560, height: 900)
}
