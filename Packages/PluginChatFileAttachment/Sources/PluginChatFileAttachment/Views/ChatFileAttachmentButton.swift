import LumiUI
import ProviderMessage
import SwiftUI
import UniformTypeIdentifiers

/// 添加文件按钮：放在 ChatActionBar 中（截图按钮右侧），点击弹出文件选择器。
///
/// 视觉风格：与 `ChatScreenshotButtonView` 协调的圆形图标按钮
/// （沿用旧版 `ChatFileAttachmentButton` 的外观）。
struct ChatFileAttachmentButton: View {
    @LumiTheme private var theme

    /// 附件写入与错误提示的窄能力；由插件入口注入。
    let capability: ChatFileAttachmentCapability

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
        .help(pluginLocalization.string("Attach file"))
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
            for url in urls {
                let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
                Task { @MainActor in
                    defer {
                        if hasSecurityScopedAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        let attachment = try await Task.detached(priority: .userInitiated) {
                            try UserFileAttachmentLoader.load(from: url)
                        }.value
                        capability.addFileAttachment(attachment)
                    } catch {
                        capability.presentLoadError(error.localizedDescription)
                    }
                }
            }
        case .failure:
            // 用户取消或读取失败时静默
            break
        }
    }
}
