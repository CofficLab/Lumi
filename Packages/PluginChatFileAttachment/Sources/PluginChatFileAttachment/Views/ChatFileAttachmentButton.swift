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

    func handle(
        _ result: Result<[URL], Error>,
        load: @escaping @Sendable (URL) async throws -> UserFileAttachment = { try UserFileAttachmentLoader.load(from: $0) }
    ) {
        switch result {
        case .success(let urls):
            // 挂起池是发送器级全局数组，读取期间切换会话后旧结果不能落入新会话（#161）。
            let conversationID = capability.selectedConversationID
            // 先同步登记全部读取，再启动批量读取：读取窗口内触发的发送会等整批结束（#1023）。
            for _ in urls {
                capability.beginAttachmentRead()
            }
            Task { @MainActor in
                defer {
                    for _ in urls {
                        capability.endAttachmentRead()
                    }
                }
                await loadAttachmentsInSelectionOrder(urls, conversationID: conversationID, load: load)
            }
        case .failure:
            // 用户取消或读取失败时静默
            break
        }
    }

    /// 并发读取每个文件，但按选择顺序收集、一次性按序回写（#424）。
    ///
    /// 完成先后取决于文件大小与 IO 时长：各自独立追加会让附件顺序随
    /// 完成顺序漂移，与用户在文件选择器里看到的顺序不一致。
    private func loadAttachmentsInSelectionOrder(
        _ urls: [URL],
        conversationID: UUID?,
        load: @escaping @Sendable (URL) async throws -> UserFileAttachment
    ) async {
        var outcomes = [Result<UserFileAttachment, Error>?](repeating: nil, count: urls.count)
        await withTaskGroup(of: (Int, Result<UserFileAttachment, Error>).self) { group in
            for (index, url) in urls.enumerated() {
                let hasSecurityScopedAccess = url.startAccessingSecurityScopedResource()
                group.addTask {
                    defer {
                        if hasSecurityScopedAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        return (index, .success(try await load(url)))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            for await (index, outcome) in group {
                outcomes[index] = outcome
            }
        }

        guard capability.selectedConversationID == conversationID else { return }
        for outcome in outcomes {
            guard let outcome else { continue }
            switch outcome {
            case .success(let attachment):
                capability.addFileAttachment(attachment)
            case .failure(let error):
                capability.recordAttachmentReadFailure()
                capability.presentLoadError(error.localizedDescription)
            }
        }
    }
}
