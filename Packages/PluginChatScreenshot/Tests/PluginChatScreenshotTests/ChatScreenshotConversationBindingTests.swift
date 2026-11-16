import CoreGraphics
import Foundation
import ProviderMessage
import Testing
@testable import PluginChatScreenshot

// MARK: - 夹具

/// 生成纯色 CGImage，供编码链路测试使用。
private func makeImage(width: Int, height: Int) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
    for i in stride(from: 0, to: pixels.count, by: 4) {
        pixels[i] = 255
        pixels[i + 1] = 255
        pixels[i + 2] = 255
        pixels[i + 3] = 255
    }
    let provider = CGDataProvider(data: Data(bytes: &pixels, count: pixels.count) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

/// 截图流程能力替身：可手动设置选中会话，并记录写回挂起池的图片附件。
@MainActor
final class ScreenshotFlowTestCapability: ScreenshotFlowCapability {
    var selectedConversationID: UUID?
    private(set) var addedImages: [UserImageAttachment] = []

    func addImageAttachment(_ attachment: UserImageAttachment) {
        addedImages.append(attachment)
    }
}

// MARK: - 会话绑定

/// 截图写回必须绑定流程启动时的会话（#422）：
/// 挂起池是发送器级全局数组，抓取 / 拖选 / 编码期间切换会话后，旧截图不能落入新会话。
/// 与文件选择读取路径 #161 同源，但发生在 ScreenCapture/Selection 回调链。
@Suite("截图流程的会话绑定", .serialized)
@MainActor
struct ChatScreenshotConversationBindingTests {

    @Test("编码期间切换会话，旧截图不落入新会话挂起池（#422）")
    func staleScreenshotDoesNotLeakIntoNewConversation() async throws {
        let a = UUID()
        let b = UUID()
        let capability = ScreenshotFlowTestCapability()
        capability.selectedConversationID = a
        let image = makeImage(width: 40, height: 20)

        // 在 A 启动写回：捕获 A 后挂起在后台编码上。
        let task = Task { @MainActor in
            await ScreenshotFlowRunner.insert(
                capability: capability,
                image: image,
                conversationID: a
            )
        }
        // 编码任务尚未让出主 actor 前同步切到 B。
        capability.selectedConversationID = b
        await task.value

        #expect(capability.addedImages.isEmpty)
    }

    @Test("未切换会话时截图正常进入挂起池（#422）")
    func screenshotInSameConversationAttaches() async throws {
        let a = UUID()
        let capability = ScreenshotFlowTestCapability()
        capability.selectedConversationID = a
        let image = makeImage(width: 40, height: 20)

        await ScreenshotFlowRunner.insert(
            capability: capability,
            image: image,
            conversationID: a
        )

        #expect(capability.addedImages.count == 1)
        #expect(capability.addedImages.first?.mimeType == "image/jpeg")
    }

    @Test("启动时无选中会话且写回时仍无会话，截图按全局池处理（#422）")
    func nilConversationStaysConsistent() async throws {
        let capability = ScreenshotFlowTestCapability()
        capability.selectedConversationID = nil
        let image = makeImage(width: 40, height: 20)

        await ScreenshotFlowRunner.insert(
            capability: capability,
            image: image,
            conversationID: nil
        )

        #expect(capability.addedImages.count == 1)
    }

    @Test("启动时无会话但写回时已选中新会话，旧截图被丢弃（#422）")
    func nilToSelectedDiscardsStaleScreenshot() async throws {
        let b = UUID()
        let capability = ScreenshotFlowTestCapability()
        capability.selectedConversationID = nil
        let image = makeImage(width: 40, height: 20)

        let task = Task { @MainActor in
            await ScreenshotFlowRunner.insert(
                capability: capability,
                image: image,
                conversationID: nil
            )
        }
        capability.selectedConversationID = b
        await task.value

        #expect(capability.addedImages.isEmpty)
    }
}