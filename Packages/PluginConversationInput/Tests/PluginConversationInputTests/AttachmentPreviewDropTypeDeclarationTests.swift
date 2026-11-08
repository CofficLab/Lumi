import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Testing
@testable import PluginConversationInput

#if os(macOS)
import AppKit

/// 预览区的拖放**类型声明**必须让 SwiftUI 保留 `public.file-url`。
///
/// ## 回归背景（真实用户缺陷）
///
/// 用户在输入框拖入第一张图片 → 上方出现附件预览 → 把第二张图片拖到
/// **预览区**上 → 什么都没发生；而同样的图片拖到输入框里却能加进去。
///
/// 根因有两层：
///
/// 1. 预览区原本没有任何拖放处理（已由 `AttachmentPreviewDropTests` 覆盖）；
/// 2. 更隐蔽的一层：SwiftUI 会按 `.onDrop(of:)` 声明的类型列表，对
///    `NSItemProvider` 做**降级**——只保留能匹配声明的表示，其余表示被丢弃。
///    声明含 `.image` 时，拖入 PNG 会让 provider 降级成 `public.png`，
///    `public.file-url` 被丢掉；路径就此不可恢复，拖放静默失败。
///
/// ## 为什么必须驱动真实的 SwiftUI drop 宿主
///
/// 手工构造 `NSItemProvider(object: URL(...) as NSURL)` **测不出**这个问题：
/// 那个 provider 自带 `public.file-url`，与降级后的形态完全不同。
///
/// 而降级发生在 SwiftUI 内部（`_PlatformDraggingDestinationView`），
/// 应用层无法直接构造「降级后的 provider」——降级后路径确实已经丢失。
/// 唯一的办法是驱动真实的 drop 宿主：喂进一个含 `public.file-url` 的
/// pasteboard，取回 SwiftUI **实际交付**的 provider，再交给解析器。
///
/// 这条链路与真实拖放完全一致，因此能真正锁住回归。
@MainActor
@Suite("附件预览区拖放类型声明")
struct AttachmentPreviewDropTypeDeclarationTests {

    // MARK: - 声明

    @Test("预览区的 onDrop 只声明 .fileURL")
    func previewDeclaresFileURLOnly() {
        // 声明里混入 .plainText / .text / .image 都会触发降级，
        // 把 public.file-url 换成不含路径的表示，拖入的图片就再也拿不到路径。
        #expect(AttachmentPreviewDropTypes.declared == [.fileURL])
    }

    // MARK: - 端到端：真实 drop 宿主 → 解析器

    @Test("SwiftUI 交付的 provider 仍带 public.file-url（图片）")
    func swiftUIKeepsFileURLForImage() async throws {
        let provider = try await deliverProvider(forPath: "/tmp/photo.png")

        #expect(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        #expect(provider.canLoadObject(ofClass: URL.self))
    }

    @Test("SwiftUI 交付的 provider 仍带 public.file-url（文本文件）")
    func swiftUIKeepsFileURLForTextFile() async throws {
        let provider = try await deliverProvider(forPath: "/tmp/notes.txt")

        #expect(provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier))
        #expect(provider.canLoadObject(ofClass: URL.self))
    }

    @Test("图片拖到预览区后能解析出路径并进入图片池")
    func droppedImageReachesImagePool() async throws {
        let capability = SendActionBarTestCapability()
        let viewModel = ConversationInputViewModel(capability: capability)

        let fileURL = try makeFile(
            named: "pixel.png",
            contents: try #require(Data(base64Encoded: attachmentTestPNGBase64))
        )
        defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

        let provider = try await deliverProvider(forPath: fileURL.path)

        let urls = await resolve([provider])
        #expect(urls.map(\.path) == [fileURL.path])

        for url in urls {
            viewModel.attach(droppedURL: url)
        }

        await waitUntil("图片附件未加入挂起池") {
            !capability.pendingImageAttachments.isEmpty
        }
        let attachment = try #require(capability.pendingImageAttachments.first)
        #expect(attachment.fileName == "pixel.png")
    }

    // MARK: - Helpers

    /// 跑一次解析并等待主线程回调。
    private func resolve(_ providers: [NSItemProvider]) async -> [URL] {
        let collector = CollectedURLs()
        await withCheckedContinuation { continuation in
            DroppedItemResolver.fileURLs(from: providers) { urls in
                collector.store(urls)
                continuation.resume()
            }
        }
        return collector.value
    }

    /// 用真实的 SwiftUI drop 宿主投递一次拖放，取回 SwiftUI 实际交付的 provider。
    ///
    /// 走的是与真实拖放完全相同的路径：pasteboard → SwiftUI 的
    /// `_PlatformDraggingDestinationView` → `.onDrop` 闭包。
    ///
    /// - Note: **不建 `NSWindow`**。`NSHostingView` 挂到 window 上后，
    ///   拖放宿主会被 AppKit 的窗口生命周期接管，测试进程结束时容易崩在
    ///   窗口清理上（signal 11）。而 drop 宿主只依赖自身注册的拖放类型，
    ///   不需要窗口即可响应——实测 `draggingEntered` / `performDragOperation`
    ///   在离屏 `NSHostingView` 上照常工作。
    private func deliverProvider(forPath path: String) async throws -> NSItemProvider {
        let collector = DeliveredProviders()
        let hosting = NSHostingView(rootView: DropProbeView(collector: collector))
        hosting.frame = NSRect(x: 0, y: 0, width: 320, height: 88)
        hosting.layoutSubtreeIfNeeded()

        // 让 SwiftUI 完成一次布局，drop 宿主才存在。
        try await Task.sleep(for: .milliseconds(200))

        let destination = try #require(findDropDestination(in: hosting))

        let pasteboard = NSPasteboard(name: .init("lumi-drop-test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.writeObjects([NSURL(fileURLWithPath: path) as NSURL])

        let info = MockDraggingInfo(pasteboard: pasteboard)
        _ = destination.draggingEntered(info)
        _ = destination.performDragOperation(info)

        try await Task.sleep(for: .milliseconds(200))

        let providers = collector.value
        #expect(providers.count == 1, "SwiftUI 未投递任何 provider")
        return try #require(providers.first)
    }

    /// 找到 SwiftUI 为 `.onDrop` 创建的拖放宿主视图。
    ///
    /// 它是私有类型，只能按「注册了拖放类型」这一行为特征识别。
    private func findDropDestination(in view: NSView) -> NSView? {
        if !view.registeredDraggedTypes.isEmpty { return view }
        for sub in view.subviews {
            if let found = findDropDestination(in: sub) { return found }
        }
        return nil
    }

    /// 在临时目录里造一个测试文件。
    private func makeFile(named name: String, contents: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("conversation-input-preview-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        let fileURL = directory.appendingPathComponent(name)
        try contents.write(to: fileURL)
        return fileURL
    }
}

/// 用与生产代码相同的类型声明接一次拖放，收集 SwiftUI 交付的 provider。
private struct DropProbeView: View {
    let collector: DeliveredProviders

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("thumb")
                    .frame(width: 72, height: 72)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 88)
        .contentShape(Rectangle())
        .onDrop(of: AttachmentPreviewDropTypes.declared, isTargeted: .constant(false)) { providers in
            collector.store(providers)
            return true
        }
    }
}

/// 收集 SwiftUI 交付的 provider。
private final class DeliveredProviders: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [NSItemProvider] = []

    func store(_ providers: [NSItemProvider]) {
        lock.lock()
        defer { lock.unlock() }
        storage = providers
    }

    var value: [NSItemProvider] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

/// 收集解析出的文件 URL。
///
/// `DroppedItemResolver` 的回调在主线程上，这里用一个 `@unchecked Sendable`
/// 盒子把值带出回调，供 `await` 之后读取。
private final class CollectedURLs: @unchecked Sendable {
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

/// 模拟拖放信息。
///
/// SwiftUI 的 drop 宿主只需要 pasteboard 与位置，不读其余字段。
///
/// - Note: `NSDraggingInfo` 的多数成员是 `@MainActor` 隔离的，因此整个类型
///   标注 `@MainActor`，与真实拖放（始终发生在主线程）一致。
@MainActor
private final class MockDraggingInfo: NSObject, @preconcurrency NSDraggingInfo {
    var draggingDestinationWindow: NSWindow?
    var draggingLocation: NSPoint = .zero
    var draggingSourceOperationMask: NSDragOperation = .copy
    var draggedImageLocation: NSPoint = .zero
    let draggingPasteboard: NSPasteboard
    var draggingSource: Any?
    var draggingSequenceNumber: Int = 1
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination: Bool = false
    var numberOfValidItemsForDrop: Int = 1
    var springLoadingHighlight: NSSpringLoadingHighlight = .none
    var draggedImage: NSImage?

    init(pasteboard: NSPasteboard) {
        self.draggingPasteboard = pasteboard
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}
    func namesOfPromisedFilesDropped(at destination: NSURL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(
        options enumOptions: NSDraggingItemEnumerationOptions,
        for view: NSView?,
        classes: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any]?,
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
}
#endif
