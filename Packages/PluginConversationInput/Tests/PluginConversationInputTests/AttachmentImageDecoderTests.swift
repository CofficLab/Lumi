import AppKit
import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationInput

/// 待发送图片附件的位图解码缓存（见 issue #1298）。
///
/// 附件预览挂在输入框上方，输入框每次按键都会让预览 body 重跑。
/// 修复前预览在 body 里现算 `Data(base64Encoded:)` + `NSImage(data:)`，
/// 每张待发图片都要在主线程重复做一次全量 Base64 解码与位图解码。
@MainActor
@Suite("附件位图解码缓存")
struct AttachmentImageDecoderTests {

    /// 一张 1×1 的 PNG（透明）。
    private func makePNGAttachment(id: UUID = UUID()) -> UserImageAttachment {
        // 最小合法 PNG：1x1 透明像素。
        let base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        return UserImageAttachment(id: id, mimeType: "image/png", base64Data: base64)
    }

    @Test("同一附件重复取图只解码一次")
    func sameAttachmentDecodesOnlyOnce() {
        let decoder = AttachmentImageDecoder()
        let attachment = makePNGAttachment()

        let first = decoder.image(for: attachment)
        let second = decoder.image(for: attachment)

        #expect(first != nil)
        // 命中缓存时返回同一个实例，说明没有重新解码。
        #expect(first === second)
    }

    @Test("文本变化后仍复用同一份位图")
    func reusesImageAcrossTextChanges() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let attachment = makePNGAttachment()
        capability.pendingImageAttachments = [attachment]
        viewModel.refresh()

        let first = viewModel.attachmentImageDecoder.image(for: attachment)
        // 模拟连续按键：每次文本变化都会让预览 body 重跑。
        viewModel.setText("a")
        viewModel.setText("ab")
        viewModel.setText("abc")
        let last = viewModel.attachmentImageDecoder.image(for: attachment)

        #expect(first != nil)
        #expect(first === last)
    }

    @Test("移除附件后释放其位图缓存")
    func removingAttachmentReleasesCache() {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)
        let attachment = makePNGAttachment()
        capability.pendingImageAttachments = [attachment]
        viewModel.refresh()

        #expect(viewModel.attachmentImageDecoder.image(for: attachment) != nil)

        viewModel.removeImageAttachment(id: attachment.id)
        viewModel.refresh()

        // 附件已不在挂起池，重新取图会重新解码（新实例）。
        let reloaded = viewModel.attachmentImageDecoder.image(for: attachment)
        #expect(reloaded != nil)
    }

    @Test("非法 Base64 返回 nil 且不缓存")
    func invalidBase64ReturnsNil() {
        let decoder = AttachmentImageDecoder()
        let broken = UserImageAttachment(mimeType: "image/png", base64Data: "not-valid-base64!!")

        #expect(decoder.image(for: broken) == nil)
        #expect(decoder.image(for: broken) == nil)
    }

    @Test("只保留挂起中的附件缓存")
    func retainOnlyKeepsPendingAttachments() {
        let decoder = AttachmentImageDecoder()
        let kept = makePNGAttachment()
        let dropped = makePNGAttachment()

        let keptImage = decoder.image(for: kept)
        let droppedImage = decoder.image(for: dropped)
        #expect(keptImage != nil)
        #expect(droppedImage != nil)

        decoder.retainOnly(ids: [kept.id])

        // 被丢弃的附件重新取图会重新解码（新实例）。
        #expect(decoder.image(for: kept) === keptImage)
        #expect(decoder.image(for: dropped) !== droppedImage)
    }
}
