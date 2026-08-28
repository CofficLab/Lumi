import LumiUI
import SwiftUI

/// Screen Recorder 插件使用手册
struct ScreenRecorderManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("Screen Recorder", "屏幕录制"),
                subtitle: L("User Manual", "使用手册")
            )

            ManualSectionHeader(number: 1, title: L("Overview", "概述"))
            Text(L("This manual covers the Screen Recorder, which captures your screen or a specific window as a video recording.", "本手册介绍屏幕录制功能,可录制全屏或指定窗口的视频。"))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Capabilities", "功能"))
            ManualBulletList(items: [
                .init(L("Record the entire screen or a specific application window.", "录制整个屏幕或指定的应用窗口。")),
                .init(L("Choose output format and quality settings.", "选择输出格式和质量设置。")),
                .init(L("Start, pause, and stop recordings from the toolbar or via agent commands.", "通过工具栏或 Agent 指令启动、暂停和停止录制。")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations", "基本操作"))
            ManualStepList(items: [
                .init(L("Open the Screen Recorder panel from the sidebar.", "从侧边栏打开屏幕录制面板。")),
                .init(L("Select the recording target: full screen or a specific window.", "选择录制目标:全屏或特定窗口。")),
                .init(L("Click the record button to start capturing.", "点击录制按钮开始捕获。")),
                .init(L("Click stop to finish; the recording is saved to your chosen location.", "点击停止完成录制,视频保存到指定位置。")),
                .init(L("You can also ask the AI to start or stop a recording.", "你也可以让 AI 帮你启动或停止录制。")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes", "注意事项"))
            ManualBulletList(items: [
                .init(L("Screen recording requires Screen Recording permission in System Settings.", "屏幕录制需要在系统设置中授予屏幕录制权限。")),
                .init(L("Large recordings may consume significant disk space.", "大型录制可能占用较多磁盘空间。")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ en: String, _ zh: String) -> String {
        ScreenRecorderLocalization.string(en, zh)
    }
}

#Preview {
    ScrollView {
        ScreenRecorderManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
