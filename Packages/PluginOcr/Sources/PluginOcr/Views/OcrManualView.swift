import LumiUI
import SwiftUI

/// OCR 插件使用手册
struct OcrManualView: View {
    @LumiTheme private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ManualHeader(
                title: L("OCR", "OCR 文字识别"),
                subtitle: L("User Manual", "使用手册")
            )

            ManualSectionHeader(number: 1, title: L("Overview", "概述"))
            Text(L("This manual covers the OCR plugin, which extracts text from images and screenshots using the on-device Vision framework.", "本手册介绍 OCR 插件,使用设备端 Vision 框架从图片和截图中提取文字。"))
                .font(.appBody)
                .foregroundColor(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ManualSectionHeader(number: 2, title: L("Capabilities", "功能"))
            ManualBulletList(items: [
                .init(L("Extract text from any image file (PNG, JPEG, HEIC, etc.).", "从任意图片文件(PNG、JPEG、HEIC 等)中提取文字。")),
                .init(L("Supports multiple languages including Chinese, English, Japanese, Korean, and more.", "支持多语言,包括中文、英文、日文、韩文等。")),
                .init(L("Fully offline processing — no network requests, no third-party APIs.", "完全离线处理 — 无网络请求,无第三方 API。")),
                .init(L("Available as both a user action and an agent tool.", "既可作为用户操作,也可作为 Agent 工具使用。")),
            ])

            ManualSectionHeader(number: 3, title: L("Basic Operations", "基本操作"))
            ManualStepList(items: [
                .init(L("Select an image in the chat or use the OCR action from the context menu.", "在聊天中选择图片,或从上下文菜单使用 OCR 操作。")),
                .init(L("The plugin processes the image locally using macOS Vision.", "插件使用 macOS Vision 在本地处理图片。")),
                .init(L("Recognized text is returned and can be copied or inserted into the conversation.", "识别的文字会返回,可复制或插入到对话中。")),
                .init(L("You can also ask the AI to perform OCR on an image by providing it in the chat.", "你也可以在聊天中提供图片,让 AI 执行 OCR。")),
            ])

            ManualSectionHeader(number: 4, title: L("Notes", "注意事项"))
            ManualBulletList(items: [
                .init(L("Recognition quality depends on image clarity and text size.", "识别质量取决于图片清晰度和文字大小。")),
                .init(L("Language hint can improve accuracy for non-English text.", "语言提示可提高非英文文字的识别准确率。")),
            ])
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func L(_ en: String, _ zh: String) -> String {
        OcrLocalization.string(en, zh)
    }
}

#Preview {
    ScrollView {
        OcrManualView()
            .padding(22)
    }
    .frame(width: 560, height: 800)
}
