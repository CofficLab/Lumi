import Combine
import Foundation
import LumiInlinePreviewKit
import MagicKit
import os
import SwiftUI

/// 内嵌预览插件的视图模型。
///
/// 职责（按阶段累积）：
/// - **Phase 2** — 管理 `InlinePreviewSession` 启动/停止；frame 转 `@Published`；canvas resize forward。
/// - **Phase 2.5a 手选 dylib** — `loadDylib(at:)` / `unloadDylib()`；用户主动选 .dylib 时进入 manual 模式，冻结自动流程。
/// - **Phase 2.5b 自动构建** — 直接订阅 `EditorService` 的 `currentFileURL` / `saveRevision` / `contentRevision`，
///   按 Xcode 风格"保存触发"重建 dylib（`InlinePreviewBuilder`）并自动 `loadDylib`。
///   **不依赖 View 层的 `onAppear`/`onChange`**——即使 Inline Preview tab 未被选中也能感知文件变化。
///
/// `renderDemoFrame()` 是 Phase 1 遗留的离线 demo 路径，仅用于验证显示链路。
@MainActor
final class EditorInlinePreviewViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.viewmodel"
    )
    nonisolated static let emoji = "🔮"
    nonisolated static let verbose: Bool = true

    // MARK: - 类型

    enum SessionStatus: Equatable, CustomStringConvertible {
        case idle
        case starting
        case running
        case stopping
        case failed(String)

        var description: String {
            switch self {
            case .idle: return "idle"
            case .starting: return "starting"
            case .running: return "running"
            case .stopping: return "stopping"
            case .failed(let msg): return "failed(\(msg))"
            }
        }
    }

    enum EntryStatus: Equatable, CustomStringConvertible {
        case demo
        case building(file: String)
        case loading(path: String)
        case loaded(path: String, title: String)
        case failed(message: String)

        var description: String {
            switch self {
            case .demo: return "demo"
            case .building(let file): return "building(\(file))"
            case .loading(let path): return "loading(\(path))"
            case .loaded(_, let title): return "loaded(\(title))"
            case .failed(let msg): return "failed(\(msg))"
            }
        }
    }

    // MARK: - 已发布状态

    @Published private(set) var currentFrame: LumiInlinePreviewFacade.IOSurfaceFrame? {
        didSet {
            if let frame = currentFrame {
                if Self.verbose {
                                    Self.logger.info("\(self.t)✅ 已设置 currentFrame：surfaceID=\(frame.surfaceID) seq=\(frame.seq) \(frame.width)×\(frame.height) @\(String(format: "%.1fx", frame.scale))")
                }
            } else {
                if Self.verbose {
                                    Self.logger.info("\(self.t)⚠️ currentFrame 设为 nil")
                }
            }
        }
    }
    @Published private(set) var canvasSize: CGSize = .zero {
        didSet {
            let oldStr = "\(oldValue.width)×\(oldValue.height)"
            let newStr = "\(canvasSize.width)×\(canvasSize.height)"
            if Self.verbose {
                            Self.logger.info("\(self.t)📐 canvasSize 变化：\(oldStr) → \(newStr)")
            }
        }
    }
    @Published private(set) var canvasScale: CGFloat = 1
    @Published private(set) var status: SessionStatus = .idle {
        didSet {
            let oldDesc = oldValue.description
            let newDesc = status.description
            if Self.verbose {
                            Self.logger.info("\(self.t)🔄 status 变化：\(oldDesc) → \(newDesc)")
            }
        }
    }
    @Published private(set) var policy: LumiInlinePreviewFacade.FrameStreamPolicy = .stopped
    @Published private(set) var entryStatus: EntryStatus = .demo {
        didSet {
            let desc = entryStatus.description
            if Self.verbose {
                            Self.logger.info("\(self.t)📦 entryStatus 变化：\(desc)")
            }
        }
    }

    // MARK: - 私有

    private let session = LumiInlinePreviewFacade.InlinePreviewSession()
    private let builder = LumiInlinePreviewFacade.InlinePreviewBuilder()
    private var demoSeq: UInt64 = 0
    private var lastSentPixelSize: (width: Int, height: Int, scale: Double)?
    /// 最近一次从编辑器收到的 (currentFileURL, source)。用于 startSession / saveRevision 时取最新内容重建。
    private var activeFileURL: URL?
    private var latestSourceText: String?
    /// 最近一次成功 loadDylib 的 build fingerprint，避免重复加载相同产物。
    private var lastLoadedFingerprint: String?
    /// 标识"用户主动手选了 dylib"——此时不应被自动 build 流程覆盖。
    private var manualDylibActive: Bool = false

    /// Combine 订阅令牌（订阅 EditorService 状态变化）。
    private var editorCancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    init() {
        if Self.verbose {
                    Self.logger.info("\(Self.t)🚩 初始化 EditorInlinePreviewViewModel")
        }
        LumiInlinePreviewFacade.verbose = Self.verbose
        wireSessionCallbacks()
    }

    /// 订阅 EditorService 的状态变化，直接感知文件切换/保存/内容变化。
    /// 不再依赖 View 层的 `onAppear`/`onChange`——即使 Inline Preview tab 未被选中也能工作。
    func wireEditorService(_ service: EditorService) {
        let state = service.state

        // 文件切换 → setActiveFile
        state.$currentFileURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self else { return }
                let sourceText = service.content?.string
                self.handleFileURLChange(url, sourceText: sourceText)
            }
            .store(in: &editorCancellables)

        // 保存 → applySaveRevision
        state.$saveRevision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let sourceText = service.content?.string
                self.handleSaveRevision(sourceText: sourceText)
            }
            .store(in: &editorCancellables)

        // 内容变化（未保存）→ updateBufferText
        state.$contentRevision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let sourceText = service.content?.string
                self.handleBufferTextUpdate(sourceText)
            }
            .store(in: &editorCancellables)

        if Self.verbose {
            Self.logger.info("\(Self.t)🔗 已订阅 EditorService 状态变化")
        }
    }

    // MARK: - 公开方法 — Demo 路径（Phase 1 遗留）

    func renderDemoFrame() {
        demoSeq &+= 1
        let pointWidth: CGFloat = canvasSize.width > 0 ? canvasSize.width : 320
        let pointHeight: CGFloat = canvasSize.height > 0 ? canvasSize.height : 180
        let scale: CGFloat = canvasScale > 0 ? canvasScale : 2

        let pixelWidth = max(1, Int((pointWidth * scale).rounded()))
        let pixelHeight = max(1, Int((pointHeight * scale).rounded()))

        let seq = demoSeq
        let canvasStr = "\(canvasSize.width)×\(canvasSize.height)"
        if Self.verbose {
                    Self.logger.info("\(self.t)🎬 渲染 Demo 帧 seq=\(seq) canvasSize=\(canvasStr) → 像素 \(pixelWidth)×\(pixelHeight) @\(String(format: "%.1f", scale))")
        }

        // 🔍 诊断：记录当前状态
        Self.logger.info("📝[renderDemoFrame] 开始渲染 Demo 帧 seq=\(seq)")
        Self.logger.info("📝[renderDemoFrame] canvasSize=\(canvasStr), canvasScale=\(self.canvasScale)")
        Self.logger.info("📝[renderDemoFrame] 计算尺寸：pointWidth=\(pointWidth), pointHeight=\(pointHeight), scale=\(scale)")
        Self.logger.info("📝[renderDemoFrame] 像素尺寸：\(pixelWidth)×\(pixelHeight)")
        
        // 检查 DemoSurfaceFactory 是否可用
        Self.logger.info("📝[renderDemoFrame] 调用 DemoSurfaceFactory.makeFrame")
        
        currentFrame = LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
            width: pixelWidth,
            height: pixelHeight,
            scale: Double(scale),
            seq: demoSeq
        )

        if let frame = currentFrame {
            Self.logger.info("📝[renderDemoFrame] ✅ Demo 帧创建成功：surfaceID=\(frame.surfaceID) seq=\(frame.seq) \(frame.width)×\(frame.height) @\(String(format: "%.1fx", frame.scale))")
        } else {
            Self.logger.error("📝[renderDemoFrame] ❌ Demo 帧创建失败 — makeFrame 返回 nil")
        }
    }

    // MARK: - 公开方法 — Session 路径

    func startSession() {
        let currentStatus = status
        guard currentStatus == .idle || isFailed(currentStatus) else {
            if Self.verbose {
                            Self.logger.warning("\(self.t)⚠️ 跳过 startSession — 当前状态=\(currentStatus.description)")
            }
            return
        }
        status = .starting
        let (pixelWidth, pixelHeight, scale) = currentPixelSize()
        if Self.verbose {
                    Self.logger.info("\(self.t)▶️ startSession 像素 \(pixelWidth)×\(pixelHeight) @\(String(format: "%.1f", scale))")
        }

        Task { [weak self] in
            do {
                try await self?.session.start()
                _ = try await self?.session.startFrameStream(width: pixelWidth, height: pixelHeight, scale: scale)
                self?.lastSentPixelSize = (pixelWidth, pixelHeight, scale)
                self?.status = .running
                if Self.verbose {
                                    Self.logger.info("\(Self.t)✅ Session 运行中，开始 autoBuildIfPossible")
                }
                // 起流后若已经有目标文件，自动 build & load。
                self?.autoBuildIfPossible()
            } catch {
                if Self.verbose {
                                    Self.logger.error("\(Self.t)❌ startSession 失败：\(error.localizedDescription)")
                }
                self?.status = .failed(error.localizedDescription)
            }
        }
    }

    func stopSession() {
        let currentStatus = status
        guard currentStatus == .running || currentStatus == .starting else {
            if Self.verbose {
                            Self.logger.warning("\(self.t)⚠️ 跳过 stopSession — 当前状态=\(currentStatus.description)")
            }
            return
        }
        if Self.verbose {
                    Self.logger.info("\(self.t)⏹ stopSession")
        }
        status = .stopping
        Task { [weak self] in
            await self?.session.stop()
            self?.status = .idle
            self?.policy = .stopped
            self?.currentFrame = nil
            if Self.verbose {
                            Self.logger.info("\(Self.t)✅ Session 已停止")
            }
        }
    }

    /// 由 `PreviewSurfaceCanvas` 在 layout / backing 变化时回调。
    func canvasDidResize(_ size: CGSize, scale: CGFloat) {
        canvasSize = size
        canvasScale = scale
        sendResizeIfNeeded()
    }

    // MARK: - 公开方法 — 输入转发（Phase 3）

    /// 由 `PreviewSurfaceCanvas` 在 `isInteractive == true` 时回调；把事件转发给子进程。
    /// 高频事件（mouseMoved / dragged / scrollWheel / keyDown 重复）走 best-effort 不阻塞。
    func forwardInputEvent(_ event: LumiInlinePreviewFacade.PreviewInputEvent) {
        guard status == .running else { return }
        session.sendInputEventBestEffort(event)
    }

    /// 当前面板是否处于"可交互"状态：session running + 已加载用户视图。
    /// Demo 视图时即便允许交互也没意义（无内容可点）；这里只在 entry 已 ready 时返回 true。
    var isInteractive: Bool {
        guard status == .running else { return false }
        switch entryStatus {
        case .loaded, .loading, .building: return true
        case .demo, .failed: return false
        }
    }

    // MARK: - 公开方法 — Entry 路径（Phase 2.5）

    /// 让子进程加载用户预览 dylib，把其 `lumi_preview_make_nsview` 导出的 `NSView` 挂为 previewView。
    func loadDylib(at url: URL) {
        manualDylibActive = true
        lastLoadedFingerprint = nil
        let path = url.path
        entryStatus = .loading(path: path)
        if Self.verbose {
                    Self.logger.info("\(self.t)📥 加载 Dylib（手动）：\(path)")
        }
        Task { [weak self] in
            do {
                let response = try await self?.session.loadDylib(path: path)
                if response?.success == true {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)✅ Dylib 已加载：\(path)")
                    }
                    self?.entryStatus = .loaded(path: path, title: (path as NSString).lastPathComponent)
                } else {
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ Dylib 加载失败：\(response?.message ?? "unknown")")
                    }
                    self?.entryStatus = .failed(message: response?.message ?? "unknown")
                }
            } catch {
                if Self.verbose {
                                    Self.logger.error("\(Self.t)❌ Dylib 加载异常：\(error.localizedDescription)")
                }
                self?.entryStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    /// 卸载用户 dylib，子进程恢复内置 demo 视图。
    func unloadDylib() {
        if Self.verbose {
                    Self.logger.info("\(self.t)📤 卸载 Dylib — 重置为 Demo 模式")
        }
        manualDylibActive = false
        lastLoadedFingerprint = nil
        Task { [weak self] in
            _ = try? await self?.session.unloadDylib()
            self?.entryStatus = .demo
        }
    }

    // MARK: - 公开方法 — 自动构建（Phase 2.5b）

    /// 由 Combine 订阅（文件 URL 变化）触发，也可由 View 层直接调用。
    func setActiveFile(_ url: URL?, sourceText: String?) {
        if Self.verbose {
                    Self.logger.info("\(self.t)📄 设置活跃文件：\(url?.lastPathComponent ?? "nil")，有源码=\(sourceText != nil)")
        }
        activeFileURL = url
        latestSourceText = sourceText
        lastLoadedFingerprint = nil
        autoBuildIfPossible()
    }

    /// 由 Combine 订阅（保存）触发，也可由 View 层直接调用。
    func applySaveRevision(sourceText: String?) {
        if Self.verbose {
                    Self.logger.info("\(self.t)💾 应用保存修订，有源码=\(sourceText != nil)")
        }
        latestSourceText = sourceText
        autoBuildIfPossible()
    }

    /// 由 Combine 订阅（内容变化）触发，也可由 View 层直接调用。
    func updateBufferText(_ sourceText: String?) {
        latestSourceText = sourceText
    }

    // MARK: - 私有 — Combine 订阅处理器

    private func handleFileURLChange(_ url: URL?, sourceText: String?) {
        setActiveFile(url, sourceText: sourceText)
    }

    private func handleSaveRevision(sourceText: String?) {
        applySaveRevision(sourceText: sourceText)
    }

    private func handleBufferTextUpdate(_ sourceText: String?) {
        updateBufferText(sourceText)
    }

    // MARK: - 私有 — 自动构建

    /// 当前文件是否值得跑自动 build。
    private func canAutoBuildActiveFile() -> Bool {
        guard !manualDylibActive else { return false }
        guard let url = activeFileURL else { return false }
        guard latestSourceText != nil else { return false }
        return url.pathExtension.lowercased() == "swift"
    }

    private func autoBuildIfPossible() {
        let currentStatus = status
        guard currentStatus == .running else {
            if Self.verbose {
                            Self.logger.info("\(self.t)⏭ 跳过 autoBuild — Session 未运行（状态=\(currentStatus.description)）")
            }
            return
        }
        guard canAutoBuildActiveFile() else {
            if !manualDylibActive, isEntryAuto() {
                if Self.verbose {
                                    Self.logger.info("\(self.t)🔄 autoBuild：无匹配文件，卸载 Dylib → Demo")
                }
                Task { [weak self] in
                    _ = try? await self?.session.unloadDylib()
                    self?.entryStatus = .demo
                    self?.lastLoadedFingerprint = nil
                }
            }
            return
        }

        guard let url = activeFileURL, let source = latestSourceText else { return }
        let displayName = url.lastPathComponent
        entryStatus = .building(file: displayName)
        if Self.verbose {
                    Self.logger.info("\(self.t)🔨 autoBuild：正在构建 \(displayName)")
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.builder.build(fileURL: url, sourceText: source)
                if Self.verbose {
                                    Self.logger.info("\(Self.t)✅ 构建成功：\(result.dylibURL.path) 指纹=\(result.fingerprint) 标题=\(result.primaryTitle)")
                }
                guard !self.manualDylibActive else { return }
                if self.lastLoadedFingerprint == result.fingerprint {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)⏭ 指纹相同，跳过加载")
                    }
                    self.entryStatus = .loaded(path: result.dylibURL.path, title: result.primaryTitle)
                    return
                }
                self.entryStatus = .loading(path: result.dylibURL.path)
                _ = try? await self.session.loadDylib(path: result.dylibURL.path)
                self.lastLoadedFingerprint = result.fingerprint
                self.entryStatus = .loaded(path: result.dylibURL.path, title: result.primaryTitle)
                if Self.verbose {
                                    Self.logger.info("\(Self.t)✅ 构建后已加载 Dylib")
                }
            } catch let error as LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError {
                switch error {
                case .noPreviewFound:
                    if Self.verbose {
                                            Self.logger.warning("\(Self.t)⚠️ 在 \(displayName) 中未找到 #Preview")
                    }
                    if self.isEntryAuto() {
                        _ = try? await self.session.unloadDylib()
                        self.entryStatus = .demo
                        self.lastLoadedFingerprint = nil
                    } else {
                        self.entryStatus = .demo
                    }
                case .sdkResolutionFailed, .swiftcFailed:
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ 构建失败：\(error.localizedDescription)")
                    }
                    self.entryStatus = .failed(message: error.localizedDescription)
                }
            } catch {
                if Self.verbose {
                                    Self.logger.error("\(Self.t)❌ 构建异常：\(error.localizedDescription)")
                }
                self.entryStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    /// 当前 entryStatus 是否对应自动 build 流程（区别于手选 dylib）。
    private func isEntryAuto() -> Bool {
        if manualDylibActive { return false }
        switch entryStatus {
        case .building, .loading, .loaded, .failed: return true
        case .demo: return false
        }
    }

    // MARK: - 私有

    private func wireSessionCallbacks() {
        session.onFrame = { [weak self] frame in
            Task { @MainActor in
                self?.currentFrame = frame
            }
        }
        session.onPolicy = { [weak self] policy in
            Task { @MainActor in
                if self != nil {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)📊 policy 变更：\(policy.rawValue)")
                    }
                }
                self?.policy = policy
            }
        }
        session.onError = { [weak self] message in
            Task { @MainActor in
                if self != nil {
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ Session 错误：\(message)")
                    }
                }
                self?.status = .failed(message)
            }
        }
        session.onTerminated = { [weak self] in
            Task { @MainActor in
                if self != nil {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)🛑 Session 已终止")
                    }
                }
                self?.status = .idle
                self?.policy = .stopped
                self?.entryStatus = .demo
            }
        }
        session.onEntryLoaded = { [weak self] success, message in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)✅ onEntryLoaded 成功：\(message ?? "nil")")
                    }
                    if case let .loading(path) = self.entryStatus {
                        let title = (path as NSString).lastPathComponent
                        self.entryStatus = .loaded(path: path, title: title)
                    }
                } else {
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ onEntryLoaded 失败：\(message ?? "nil")")
                    }
                    self.entryStatus = .failed(message: message ?? "unknown")
                }
            }
        }
    }

    private func currentPixelSize() -> (Int, Int, Double) {
        let pointWidth: CGFloat = canvasSize.width > 0 ? canvasSize.width : 320
        let pointHeight: CGFloat = canvasSize.height > 0 ? canvasSize.height : 180
        let scale: CGFloat = canvasScale > 0 ? canvasScale : 2
        let pixelWidth = max(1, Int((pointWidth * scale).rounded()))
        let pixelHeight = max(1, Int((pointHeight * scale).rounded()))
        return (pixelWidth, pixelHeight, Double(scale))
    }

    private func sendResizeIfNeeded() {
        guard status == .running else { return }
        let (w, h, s) = currentPixelSize()
        if let last = lastSentPixelSize, last == (w, h, s) { return }
        lastSentPixelSize = (w, h, s)
        if Self.verbose {
                    Self.logger.info("\(self.t)📐 sendResize：\(w)×\(h) @\(String(format: "%.1f", s))")
        }
        Task { [weak self] in
            _ = try? await self?.session.resize(width: w, height: h, scale: s)
        }
    }

    private func isFailed(_ status: SessionStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }
}
