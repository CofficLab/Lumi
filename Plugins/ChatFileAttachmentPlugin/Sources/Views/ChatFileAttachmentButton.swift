import LumiKernel
import LumiUI
import SwiftUI

/// 添加文件按钮:放在 ChatActionBar 中(截图按钮右侧),点击弹出文件选择器。
///
/// 视觉风格:与 `ChatScreenshotButtonView` 协调的圆形图标按钮。
struct ChatFileAttachmentButton: View {
    @ObservedObject var kernel: LumiKernel
    @LumiTheme private var theme

    /// 控制 `.fileImporter` 显隐
    @State private var showImporter = false

    var body: some View {
        Button {
            showImporter = true
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(theme.textPrimary.opacity(0.07), in: Circle())
        }
        .buttonStyle(.plain)
        .help("Attach file")
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handle(result)
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let outcome = FileAttachmentBuilder.build(from: urls)
            for image in outcome.images {
                kernel.messageSender?.addAttachment(image)
            }
            for file in outcome.files {
                kernel.messageSender?.addFileAttachment(file)
            }
        case .failure:
            // 用户取消或读取失败时静默
            break
        }
    }
}
