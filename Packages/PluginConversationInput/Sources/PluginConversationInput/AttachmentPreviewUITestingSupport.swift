#if DEBUG
import Foundation
import ProviderMessage
import ProviderMessageSender

/// 附件预览的 UI 测试夹具（仅 DEBUG）。
///
/// 当 App 以 `--lumi-ui-testing-attachment-preview` 启动时，本夹具向发送器的
/// 挂起池写入 2 张图片 + 2 个文件，让 `AttachmentPreviewView` 在无拖放手势的
/// 情况下稳定渲染出缩略图与 chip。
///
/// ## 为什么需要夹具而不是真的拖放
///
/// `LumiSendActionBarUITests` 已记录实测结论：XCUITest 的坐标拖放在 SwiftUI 的
/// drop destination 上不稳定，剪贴板方案不可靠，文件选择器会被系统面板打断。
/// 拖放路径因此只由单元测试覆盖。
///
/// 但「✕ 按钮点了会不会真的生效」这个问题**必须在真实界面上回答**：
/// 单元测试只能断言 ViewModel 的数组，而按钮的命中区域、被父容器裁剪、
/// SwiftUI 手势竞争（预览行嵌在 `ScrollView` 里）都只存在于真实渲染中。
/// 夹具把这部分的不确定性收敛掉，让 ✕ 的点击可以稳定断言。
///
/// - Note: 夹具只写入初始挂起池，不替换任何 Provider 行为；点击 ✕ 走的是
///   生产路径（`AttachmentThumbnail.onRemove` → ViewModel → capability →
///   `DefaultMessageSender.removeImageAttachment`）。
@MainActor
public enum AttachmentPreviewUITestingSupport {
    /// 启用本夹具的启动参数。
    public static let launchArgument = "--lumi-ui-testing-attachment-preview"

    /// 文本附件的文件名。UI 测试据此确认对应 chip 已渲染。
    public static let textFileName = "ui-test-preview.txt"

    /// 二进制附件的文件名。用于覆盖「二进制文件」副标题分支。
    public static let binaryFileName = "ui-test-preview.bin"

    /// 两张图片附件的文件名。
    ///
    /// 覆盖「移除其一后其余不受影响」——单张图片的预览无法区分
    /// 「点了这个」与「碰巧删对了唯一的那个」。
    public static let imageFileNames = ["ui-test-preview-a.png", "ui-test-preview-b.png"]

    /// 1×1 PNG 的 base64。
    ///
    /// 用真实 PNG 而非 `"AAAA"`：占位符也会走同一条渲染分支，但真实像素
    /// 能顺带验证 `NSImage(data:)` 解码成功（解码失败会退化成灰色占位块，
    /// 而这在 AX 树上与正常缩略图几乎无法区分）。
    private static let onePixelPNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains(launchArgument)
    }

    /// 写入确定性附件，使预览行渲染出 2 张图片缩略图 + 2 个文件 chip。
    ///
    /// - Note: 必须在 ChatSection / Observer 装配**之后**调用：写入挂起池会触发
    ///   `.attachmentsChanged`，若此时没有订阅者，预览不会刷新。插件在
    ///   `onReady` 阶段调用即可。
    public static func seedAttachments(into sender: any MessageSendingProviding) {
        guard isEnabled else { return }

        for name in imageFileNames {
            sender.addImageAttachment(
                UserImageAttachment(
                    mimeType: "image/png",
                    base64Data: onePixelPNG,
                    fileName: name
                )
            )
        }

        sender.addFileAttachment(
            UserFileAttachment(
                fileName: textFileName,
                mimeType: "text/plain",
                textContent: "UI Testing Attachment Preview"
            )
        )
        sender.addFileAttachment(
            UserFileAttachment(
                fileName: binaryFileName,
                mimeType: "application/octet-stream",
                textContent: nil
            )
        )
    }
}
#endif
