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
/// - **Phase 2.5b 自动构建** — `setActiveFile(_:sourceText:)` / `applySaveRevision(sourceText:)` /
///   `updateBufferText(_:)`：跟随编辑器的 `currentFileURL` + `saveRevision` + `contentRevision`，
///   按 Xcode 风格"保存触发"重建 dylib（`InlinePreviewBuilder`）并自动 `loadDylib`。
///
/// `renderDemoFrame()` 是 Phase 1 遗留的离线 demo 路径，仅用于验证显示链路。
@MainActor
final class EditorInlinePreviewViewModel: ObservableObject, SuperLog {
    nonisolated static let emoji = "🔮"

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
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("\(self.t)✅ currentFrame set: surfaceID=\(frame.surfaceID) seq=\(frame.seq) \(frame.width)×\(frame.height) @\(String(format: "%.1fx", frame.scale))")
                }
            } else {
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("\(self.t)⚠️ currentFrame set to nil")
                }
            }
        }
    }
    @Published private(set) var canvasSize: CGSize = .zero {
        didSet {
            let oldStr = "\(oldValue.width)×\(oldValue.height)"
            let newStr = "\(canvasSize.width)×\(canvasSize.height)"
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("\(self.t)📐 canvasSize changed: \(oldStr) → \(newStr)")
            }
        }
    }
    @Published private(set) var canvasScale: CGFloat = 1
    @Published private(set) var status: SessionStatus = .idle {
        didSet {
            let oldDesc = oldValue.description
            let newDesc = status.description
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("\(self.t)🔄 status changed: \(oldDesc) → \(newDesc)")
            }
        }
    }
    @Published private(set) var policy: LumiInlinePreviewFacade.FrameStreamPolicy = .stopped
    @Published private(set) var entryStatus: EntryStatus = .demo {
        didSet {
            let desc = entryStatus.description
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("\(self.t)📦 entryStatus changed: \(desc)")
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

    // MARK: - 初始化

    init() {
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(Self.t)🚩 Init EditorInlinePreviewViewModel")
        }
        LumiInlinePreviewFacade.verbose = EditorInlinePreviewPlugin.verbose
        wireSessionCallbacks()
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
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)🎬 renderDemoFrame seq=\(seq) canvasSize=\(canvasStr) → pixel \(pixelWidth)×\(pixelHeight) @\(String(format: "%.1f", scale))")
        }

        currentFrame = LumiInlinePreviewFacade.DemoSurfaceFactory.makeFrame(
            width: pixelWidth,
            height: pixelHeight,
            scale: Double(scale),
            seq: demoSeq
        )

        if currentFrame != nil {
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("\(self.t)✅ Demo frame created successfully")
            }
        } else {
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.error("\(self.t)❌ Demo frame creation FAILED — makeFrame returned nil")
            }
        }
    }

    // MARK: - 公开方法 — Session 路径

    func startSession() {
        let currentStatus = status
        guard currentStatus == .idle || isFailed(currentStatus) else {
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.warning("\(self.t)⚠️ startSession skipped — status=\(currentStatus.description)")
            }
            return
        }
        status = .starting
        let (pixelWidth, pixelHeight, scale) = currentPixelSize()
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)▶️ startSession pixel \(pixelWidth)×\(pixelHeight) @\(String(format: "%.1f", scale))")
        }

        Task { [weak self] in
            do {
                try await self?.session.start()
                _ = try await self?.session.startFrameStream(width: pixelWidth, height: pixelHeight, scale: scale)
                self?.lastSentPixelSize = (pixelWidth, pixelHeight, scale)
                self?.status = .running
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("\(Self.t)✅ Session running, starting autoBuildIfPossible")
                }
                // 起流后若已经有目标文件，自动 build & load。
                self?.autoBuildIfPossible()
            } catch {
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ startSession failed: \(error.localizedDescription)")
                }
                self?.status = .failed(error.localizedDescription)
            }
        }
    }

    func stopSession() {
        let currentStatus = status
        guard currentStatus == .running || currentStatus == .starting else {
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.warning("\(self.t)⚠️ stopSession skipped — status=\(currentStatus.description)")
            }
            return
        }
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)⏹ stopSession")
        }
        status = .stopping
        Task { [weak self] in
            await self?.session.stop()
            self?.status = .idle
            self?.policy = .stopped
            self?.currentFrame = nil
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("\(Self.t)✅ Session stopped")
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
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)📥 loadDylib (manual): \(path)")
        }
        Task { [weak self] in
            do {
                let response = try await self?.session.loadDylib(path: path)
                if response?.success == true {
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.info("\(Self.t)✅ Dylib loaded: \(path)")
                    }
                    self?.entryStatus = .loaded(path: path, title: (path as NSString).lastPathComponent)
                } else {
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ Dylib load failed: \(response?.message ?? "unknown")")
                    }
                    self?.entryStatus = .failed(message: response?.message ?? "unknown")
                }
            } catch {
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ Dylib load error: \(error.localizedDescription)")
                }
                self?.entryStatus = .failed(message: error.localizedDescription)
            }
        }
    }

    /// 卸载用户 dylib，子进程恢复内置 demo 视图。
    func unloadDylib() {
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)📤 unloadDylib — resetting to demo mode")
        }
        manualDylibActive = false
        lastLoadedFingerprint = nil
        Task { [weak self] in
            _ = try? await self?.session.unloadDylib()
            self?.entryStatus = .demo
        }
    }

    // MARK: - 公开方法 — 自动构建（Phase 2.5b）

    /// 由 View 在 `currentFileURL` 改变时调用。stash 当前文件 + 源文，session running 时立即重建。
    func setActiveFile(_ url: URL?, sourceText: String?) {
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)📄 setActiveFile: \(url?.lastPathComponent ?? "nil"), hasSource=\(sourceText != nil)")
        }
        activeFileURL = url
        latestSourceText = sourceText
        lastLoadedFingerprint = nil
        autoBuildIfPossible()
    }

    /// 由 View 在 `saveRevision` 改变时调用——即用户按下了 Cmd+S。
    func applySaveRevision(sourceText: String?) {
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)💾 applySaveRevision, hasSource=\(sourceText != nil)")
        }
        latestSourceText = sourceText
        autoBuildIfPossible()
    }

    /// 由 View 在 buffer 内容变化（未保存）时调用——只更新 stash，不触发重建。
    func updateBufferText(_ sourceText: String?) {
        latestSourceText = sourceText
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
            if EditorInlinePreviewPlugin.verbose {
                            EditorInlinePreviewPlugin.logger.info("\(self.t)⏭ autoBuild skipped — session not running (status=\(currentStatus.description))")
            }
            return
        }
        guard canAutoBuildActiveFile() else {
            if !manualDylibActive, isEntryAuto() {
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("\(self.t)🔄 autoBuild: no eligible file, unloading dylib → demo")
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
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)🔨 autoBuild: building \(displayName)")
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.builder.build(fileURL: url, sourceText: source)
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("\(Self.t)✅ Build succeeded: \(result.dylibURL.path) fingerprint=\(result.fingerprint) title=\(result.primaryTitle)")
                }
                guard !self.manualDylibActive else { return }
                if self.lastLoadedFingerprint == result.fingerprint {
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.info("\(Self.t)⏭ Same fingerprint, skipping load")
                    }
                    self.entryStatus = .loaded(path: result.dylibURL.path, title: result.primaryTitle)
                    return
                }
                self.entryStatus = .loading(path: result.dylibURL.path)
                _ = try? await self.session.loadDylib(path: result.dylibURL.path)
                self.lastLoadedFingerprint = result.fingerprint
                self.entryStatus = .loaded(path: result.dylibURL.path, title: result.primaryTitle)
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.info("\(Self.t)✅ Dylib loaded after build")
                }
            } catch let error as LumiInlinePreviewFacade.InlinePreviewBuilder.BuildError {
                switch error {
                case .noPreviewFound:
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.warning("\(Self.t)⚠️ No #Preview found in \(displayName)")
                    }
                    if self.isEntryAuto() {
                        _ = try? await self.session.unloadDylib()
                        self.entryStatus = .demo
                        self.lastLoadedFingerprint = nil
                    } else {
                        self.entryStatus = .demo
                    }
                case .sdkResolutionFailed, .swiftcFailed:
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ Build failed: \(error.localizedDescription)")
                    }
                    self.entryStatus = .failed(message: error.localizedDescription)
                }
            } catch {
                if EditorInlinePreviewPlugin.verbose {
                                    EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ Build error: \(error.localizedDescription)")
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
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.info("\(Self.t)📊 policy changed: \(policy.rawValue)")
                    }
                }
                self?.policy = policy
            }
        }
        session.onError = { [weak self] message in
            Task { @MainActor in
                if self != nil {
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ Session error: \(message)")
                    }
                }
                self?.status = .failed(message)
            }
        }
        session.onTerminated = { [weak self] in
            Task { @MainActor in
                if self != nil {
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.info("\(Self.t)🛑 Session terminated")
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
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.info("\(Self.t)✅ onEntryLoaded success: \(message ?? "nil")")
                    }
                    if case let .loading(path) = self.entryStatus {
                        let title = (path as NSString).lastPathComponent
                        self.entryStatus = .loaded(path: path, title: title)
                    }
                } else {
                    if EditorInlinePreviewPlugin.verbose {
                                            EditorInlinePreviewPlugin.logger.error("\(Self.t)❌ onEntryLoaded failed: \(message ?? "nil")")
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
        if EditorInlinePreviewPlugin.verbose {
                    EditorInlinePreviewPlugin.logger.info("\(self.t)📐 sendResize: \(w)×\(h) @\(String(format: "%.1f", s))")
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
