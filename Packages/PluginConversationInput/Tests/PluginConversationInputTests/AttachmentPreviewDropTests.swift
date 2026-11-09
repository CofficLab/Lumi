import Foundation
import ProviderMessage
import ProviderMessageSender
import Testing
import UniformTypeIdentifiers
@testable import PluginConversationInput

/// 附件预览区作为**拖放落点**的行为。
///
/// ## 回归背景（真实用户缺陷）
///
/// 用户在输入框拖入一张图片 → 上方出现附件预览 → 用户把第二张图片拖到
/// **预览区**上 → 什么都没发生。
///
/// 根因：预览区（`AttachmentPreviewView`）只渲染缩略图，没有任何拖放处理。
/// 而输入框是 AppKit 的 `NSTextView`，它自己实现了 `performDragOperation`，
/// 两处是两套完全独立的拖放路径——预览区没有对应实现，拖放就落到了
/// 预览区之外的空白处，表现为「没反应」。
///
/// 本套件覆盖三件事：
///
/// 1. 预览区的拖放解析（`DroppedItemResolver`）能把 provider 还原成文件 URL；
/// 2. 分流规则（`attach(droppedURL:)`）把文件送到正确的落点；
/// 3. 解析顺序稳定——附件缩略图的顺序必须跟随拖放顺序，而不是各 provider
///    的取回时序。
@MainActor
@Suite("附件预览区拖放")
struct AttachmentPreviewDropTests {

    // MARK: - Provider → 文件 URL

    @Test("file-url 表示的 provider 被解析为文件 URL")
    func fileURLProviderResolvesToLocalURL() async {
        let provider = NSItemProvider(
            object: URL(fileURLWithPath: "/tmp/photo.png") as NSURL
        )

        let urls = await resolve([provider])

        #expect(urls.map(\.path) == ["/tmp/photo.png"])
    }

    @Test("纯文本路径的 provider 被解析为文件 URL")
    func plainTextProviderResolvesToLocalURL() async {
        // 编辑器里选中的路径拖进来就是纯文本，没有 file-url 表示。
        let provider = NSItemProvider(object: "/tmp/notes.txt" as NSString)

        let urls = await resolve([provider])

        #expect(urls.map(\.path) == ["/tmp/notes.txt"])
    }

    @Test("归档过的纯文本表示同样能解出路径")
    func archivedPlainTextProviderResolvesToLocalURL() async {
        // `public.plain-text` 的内容可能是 NSKeyedArchiver 包过的字符串，
        // 直接按 UTF-8 解会失败（不是合法 UTF-8）。
        let archived = try! NSKeyedArchiver.archivedData(
            withRootObject: "/tmp/archived.txt" as NSString,
            requiringSecureCoding: true
        )
        let provider = NSItemProvider(item: archived as NSData, typeIdentifier: UTType.plainText.identifier)

        let urls = await resolve([provider])

        #expect(urls.map(\.path) == ["/tmp/archived.txt"])
    }

    @Test("非文件内容（普通文本段落）不产出文件 URL")
    func nonPathTextYieldsNoURL() async {
        let provider = NSItemProvider(object: "just some notes" as NSString)

        let urls = await resolve([provider])

        #expect(urls.isEmpty)
    }

    @Test("空 provider 列表产出空结果")
    func emptyProviderListYieldsNoURL() async {
        let urls = await resolve([])

        #expect(urls.isEmpty)
    }

    @Test("声称有文本表示却取不出内容的 provider 不会崩溃")
    func providerWithUnreadableRepresentationDoesNotCrash() async {
        // 有些应用的拖放只登记了类型标识，却不提供可读数据。
        // 解析必须安全地放弃，而不是在表示数组上越界崩溃。
        let provider = NSItemProvider(item: Data() as NSData, typeIdentifier: UTType.plainText.identifier)

        let urls = await resolve([provider])

        #expect(urls.isEmpty)
    }

    // MARK: - 顺序稳定性

    @Test("多个 provider 的解析结果按拖放顺序排列")
    func multipleProvidersKeepDropOrder() async {
        let paths = ["/tmp/a.png", "/tmp/b.png", "/tmp/c.png"]
        let providers = paths.map {
            NSItemProvider(object: URL(fileURLWithPath: $0) as NSURL)
        }

        let urls = await resolve(providers)

        #expect(urls.map(\.path) == paths)
    }

    // MARK: - 分流规则

    @Test("拖入预览区的图片进入图片池")
    func droppedImageGoesToImagePool() async throws {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let fileURL = try makeFile(
            named: "pixel.png",
            contents: try #require(Data(base64Encoded: attachmentTestPNGBase64))
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        viewModel.attach(droppedURL: fileURL)

        await waitUntil("图片附件未加入挂起池") {
            !capability.pendingImageAttachments.isEmpty
        }

        let attachment = try #require(capability.pendingImageAttachments.first)
        #expect(attachment.fileName == "pixel.png")
        #expect(attachment.mimeType == "image/png")
    }

    @Test("拖入预览区的普通文件进入文件池")
    func droppedFileGoesToFilePool() async throws {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let fileURL = try makeFile(named: "notes.txt", contents: Data("hello".utf8))
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }
        viewModel.attach(droppedURL: fileURL)

        await waitUntil("文件附件未加入挂起池") {
            !capability.pendingFileAttachments.isEmpty
        }

        let attachment = try #require(capability.pendingFileAttachments.first)
        #expect(attachment.fileName == "notes.txt")
        #expect(attachment.textContent == "hello")
    }

    @Test("拖入预览区的目录路径交给输入框编辑器插入")
    func droppedDirectoryQueuesPathForEditor() async throws {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-preview-dir-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }

        viewModel.attach(droppedURL: directory)

        #expect(viewModel.pendingBlock?.text == directory.path)
    }

    @Test("预览区与输入框共用同一套分流规则")
    func previewAndEditorShareTheSameRoutingRule() async throws {
        // 同一个文件，走预览区的落点与走输入框的落点，结果必须一致。
        let previewCapability = SendActionBarTestCapability()
        let previewViewModel = ConversationInputViewModel(capability: previewCapability)

        let editorCapability = SendActionBarTestCapability()
        let editorViewModel = ConversationInputViewModel(capability: editorCapability)

        let fileURL = try makeFile(
            named: "shared.png",
            contents: try #require(Data(base64Encoded: attachmentTestPNGBase64))
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        previewViewModel.attach(droppedURL: fileURL)
        editorViewModel.attachImage(fileURL)

        await waitUntil("图片附件未加入挂起池") {
            !previewCapability.pendingImageAttachments.isEmpty
                && !editorCapability.pendingImageAttachments.isEmpty
        }

        let previewed = try #require(previewCapability.pendingImageAttachments.first)
        let edited = try #require(editorCapability.pendingImageAttachments.first)
        #expect(previewed.fileName == edited.fileName)
        #expect(previewed.mimeType == edited.mimeType)
        #expect(previewed.base64Data == edited.base64Data)
    }

    // MARK: - Helpers

    /// 跑一次解析并等待主线程回调。
    private func resolve(_ providers: [NSItemProvider]) async -> [URL] {
        let collector = ResolvedURLs()
        await withCheckedContinuation { continuation in
            DroppedItemResolver.fileURLs(from: providers) { urls in
                collector.store(urls)
                continuation.resume()
            }
        }
        return collector.value
    }

    /// 在临时目录里造一个测试文件。
    ///
    /// 文件放在一个唯一命名的子目录里，**文件名保持原样**——附件的
    /// `fileName` 取自 `url.lastPathComponent`，若文件名带上唯一化前缀，
    /// 断言就失去了意义。
    ///
    /// 清理时删掉整个子目录（`fileURL.deletingLastPathComponent()`）。
    private func makeFile(named name: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-preview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let fileURL = directory.appendingPathComponent(name)
        try contents.write(to: fileURL)
        return fileURL
    }
}

/// 收集解析结果。
///
/// `DroppedItemResolver` 的回调在主线程上，这里用一个 `@unchecked Sendable`
/// 盒子把值带出回调，供 `await` 之后读取。
private final class ResolvedURLs: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func store(_ urls: [URL]) {
        lock.lock()
        defer { lock.unlock() }
        storage = urls
    }

    var value: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
