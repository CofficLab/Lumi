import Combine
import EditorService
import Foundation
import LumiCoreKit
import LumiPreviewKit
import os
import SuperLogKit
import SwiftUI
import StringCatalogKit

/// 预览插件的视图模型。
///
/// 职责：
/// - 管理 `InlinePreviewSession` 启动/停止；frame 转 `@Published`；canvas resize forward。
/// - 自动构建：直接订阅 `EditorService` 的 `currentFileURL` / `saveRevision` / `contentRevision`，
///   按 Xcode 风格"保存触发"重建 dylib（`PreviewBuilder`）并自动 `loadDylib`。
///   **不依赖 View 层的 `onAppear`/`onChange`**——即使 Inline Preview tab 未被选中也能感知文件变化。
@MainActor
public final class EditorPreviewViewModel: ObservableObject, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.viewmodel"
    )
    public nonisolated static let emoji = "🔮"
    public nonisolated static let verbose: Bool = true

    // MARK: - 类型

    enum SessionStatus: Equatable, CustomStringConvertible {
        case idle
        case warming
        case ready
        case starting
        case running
        case stopping
        case failed(String)

        var description: String {
            switch self {
            case .idle: return "idle"
            case .warming: return "warming"
            case .ready: return "ready"
            case .starting: return "starting"
            case .running: return "running"
            case .stopping: return "stopping"
            case .failed(let msg): return "failed(\(msg))"
            }
        }
    }

    enum EntryStatus: Equatable, CustomStringConvertible {
        case noPreview
        case building(file: String)
        case loading(path: String)
        case loaded(path: String, title: String)
        case failed(EntryFailure)

        var description: String {
            switch self {
            case .noPreview: return "noPreview"
            case .building(let file): return "building(\(file))"
            case .loading(let path): return "loading(\(path))"
            case .loaded(_, let title): return "loaded(\(title))"
            case .failed(let failure): return "failed(\(failure.kind.rawValue): \(failure.message))"
            }
        }
    }

    enum EntryFailureKind: String, Equatable {
        case sdk
        case compile
        case dependency
        case dylibLoad
        case unknown
    }

    struct EntryFailure: Equatable {
        let kind: EntryFailureKind
        let message: String

        var title: String {
            switch kind {
            case .sdk:
                return LumiPluginLocalization.string("SDK resolution failed", bundle: .module)
            case .compile:
                return LumiPluginLocalization.string("Compilation failed", bundle: .module)
            case .dependency:
                return LumiPluginLocalization.string("Dependency planning failed", bundle: .module)
            case .dylibLoad:
                return LumiPluginLocalization.string("Preview dylib failed to load", bundle: .module)
            case .unknown:
                return LumiPluginLocalization.string("Preview failed", bundle: .module)
            }
        }

        var systemImage: String {
            switch kind {
            case .sdk:
                return "gear.badge.questionmark"
            case .compile:
                return "curlybraces"
            case .dependency:
                return "shippingbox"
            case .dylibLoad:
                return "link.badge.plus"
            case .unknown:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    enum PreviewMode: Equatable {
        case swift
        case image(URL)
        case markdown(URL)
        case stringCatalog(URL)
        case json(URL)
        case plist(URL)
        case csv(URL)
        case html(URL)
        case pdf(URL)
        case xcassets(URL)
        case doc(URL)
        case unsupported(URL?)
    }

    struct BuildInfo: Equatable {
        let completedAt: Date
        let usedCache: Bool
        let previewCount: Int
        let selectedTitle: String
    }

    struct StringCatalogProjectCleanSummary: Equatable, Sendable {
        let scannedFileCount: Int
        let changedFileCount: Int
        let removedEntryCount: Int
    }

    // MARK: - 已发布状态

    @Published private(set) var currentFrame: LumiPreviewFacade.IOSurfaceFrame?
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
    @Published private(set) var policy: LumiPreviewFacade.FrameStreamPolicy = .stopped
    @Published private(set) var entryStatus: EntryStatus = .noPreview {
        didSet {
            let desc = entryStatus.description
            if Self.verbose {
                            Self.logger.info("\(self.t)📦 entryStatus 变化：\(desc)")
            }
        }
    }
    @Published private(set) var previewMode: PreviewMode = .unsupported(nil)
    @Published private(set) var availablePreviews: [LumiPreviewFacade.PreviewBuilder.PreviewSummary] = []
    @Published private(set) var selectedPreviewIndex: Int = 0
    @Published private(set) var lastBuildInfo: BuildInfo?
    @Published private(set) var cacheSummary: EditorPreviewStorage.CacheSummary = .init(fileCount: 0, byteCount: 0)
    @Published private(set) var entryDebugState: String?
    @Published private(set) var isRequestingEntryDebugState = false
    @Published private(set) var cursorShape: LumiPreviewFacade.PreviewCursorShape = .arrow
    /// 最近一次构建失败时写入的日志文件 URL，用于在 UI 上提供「查看日志文件」入口。
    @Published private(set) var lastBuildLogURL: URL?

    // MARK: - 私有

    private let session: LumiPreviewFacade.InlinePreviewSession
    private let builder: LumiPreviewFacade.PreviewBuilder
    private var lastSentPixelSize: (width: Int, height: Int, scale: Double)?
    /// 最近一次从编辑器收到的 (currentFileURL, source)。用于 startSession / saveRevision 时取最新内容重建。
    private var activeFileURL: URL?
    private var latestSourceText: String?
    /// 最近一次成功 loadDylib 的 build fingerprint，避免重复加载相同产物。
    private var lastLoadedFingerprint: String?
    private var isViewVisible = false
    private var didWireEditorService = false
    private var warmupTask: Task<Void, Never>?
    private var pendingCanvasResizeTask: Task<Void, Never>?
    private var cacheSummaryTask: Task<Void, Never>?
    private var lastFrameSeq: UInt64?
    private var receivedFrameCount: UInt64 = 0
    /// 每次切换文件或启动一次新的 build 都递增，用于丢弃旧文件/旧构建的异步回调。
    private var previewGeneration: UInt64 = 0

    /// Combine 订阅令牌（订阅 EditorService 状态变化）。
    private var editorCancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    public init() {
        EditorPreviewStorage.installIfNeeded()
        session = LumiPreviewFacade.InlinePreviewSession()
        let xcodeCompiler = LumiPreviewFacade.XcodeCompiler(
            derivedDataPath: EditorPreviewStorage.derivedDataDirectory
        )
        builder = LumiPreviewFacade.PreviewBuilder(
            workspaceRoot: EditorPreviewStorage.inlineBuilderWorkspaceDirectory,
            xcodeCompiler: xcodeCompiler
        )
        if Self.verbose {
                    Self.logger.info("\(Self.t)🚩 初始化 EditorPreviewViewModel")
        }
        LumiPreviewFacade.verbose = Self.verbose
        wireSessionCallbacks()
        refreshCacheSummary()
    }

    deinit {
        cacheSummaryTask?.cancel()
    }

    /// 订阅 EditorService 的状态变化，直接感知文件切换/保存/内容变化。
    /// 不再依赖 View 层的 `onAppear`/`onChange`——即使 Inline Preview tab 未被选中也能工作。
    public func wireEditorService(_ service: EditorService) {
        guard !didWireEditorService else { return }
        didWireEditorService = true
        let state = service.state

        // 文件切换 → setActiveFile
        state.$currentFileURL
            .receive(on: DispatchQueue.main)
            .sink { [weak self] url in
                guard let self else { return }
                let sourceText = service.files.content?.string
                self.handleFileURLChange(url, sourceText: sourceText)
            }
            .store(in: &editorCancellables)

        // 保存 → applySaveRevision
        state.$saveRevision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let sourceText = service.files.content?.string
                self.handleSaveRevision(sourceText: sourceText)
            }
            .store(in: &editorCancellables)

        // 内容变化（未保存）→ updateBufferText
        state.$contentRevision
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let sourceText = service.files.content?.string
                self.handleBufferTextUpdate(sourceText)
            }
            .store(in: &editorCancellables)

        if Self.verbose {
            Self.logger.info("\(Self.t)🔗 已订阅 EditorService 状态变化")
        }
    }

    public func viewDidAppear(fileURL: URL?, sourceText: String?) {
        isViewVisible = true
        if Self.canPrepareInlinePreview(fileURL: fileURL, sourceText: sourceText) {
            warmupSessionIfPossible()
        }
        setActiveFile(fileURL, sourceText: sourceText)
        startSessionIfNeededForActiveFile()
    }

    public func viewDidDisappear() {
        isViewVisible = false
        stopSessionIfNeeded()
    }

    // MARK: - 公开方法 — Session 路径

    public func startSession() {
        let currentStatus = status
        if currentStatus == .warming {
            Task { [weak self] in
                await self?.warmupTask?.value
                guard self?.isViewVisible == true else { return }
                self?.startSession()
            }
            return
        }
        guard currentStatus == .idle || currentStatus == .ready || isFailed(currentStatus) else {
            if Self.verbose {
                            Self.logger.warning("\(self.t)⚠️ 跳过 startSession — 当前状态=\(currentStatus.description, privacy: .public)")
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

    public func stopSession() {
        stopSession(restartIfStillNeeded: false)
    }

    private func stopSession(restartIfStillNeeded: Bool) {
        let currentStatus = status
        guard currentStatus == .running ||
              currentStatus == .starting ||
              currentStatus == .warming ||
              currentStatus == .ready else {
            if Self.verbose {
                            Self.logger.warning("\(self.t)⚠️ 跳过 stopSession — 当前状态=\(currentStatus.description, privacy: .public)")
            }
            return
        }
        if Self.verbose {
                    Self.logger.info("\(self.t)⏹ stopSession")
        }
        status = .stopping
        Task { [weak self] in
            let warmupTask = self?.warmupTask
            warmupTask?.cancel()
            self?.warmupTask = nil
            if let warmupTask {
                await warmupTask.value
            }
            await self?.session.stop()
            self?.status = .idle
            self?.policy = .stopped
            self?.currentFrame = nil
            self?.entryStatus = .noPreview
            self?.lastLoadedFingerprint = nil
            self?.entryDebugState = nil
            self?.cursorShape = .arrow
            if restartIfStillNeeded,
               let self,
               Self.shouldRestartAfterStop(
                   isViewVisible: self.isViewVisible,
                   previewMode: self.previewMode,
                   sourceText: self.latestSourceText
               ) {
                self.startSessionIfNeededForActiveFile()
            }
            if Self.verbose {
                            Self.logger.info("\(Self.t)✅ Session 已停止")
            }
        }
    }

    /// 由 `PreviewSurfaceCanvas` 在 layout / backing 变化时回调。
    public func canvasDidResize(_ size: CGSize, scale: CGFloat) {
        guard canvasSize != size || canvasScale != scale else { return }
        pendingCanvasResizeTask?.cancel()
        pendingCanvasResizeTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            self.canvasSize = size
            self.canvasScale = scale
            self.sendResizeIfNeeded()
            self.pendingCanvasResizeTask = nil
        }
    }

    // MARK: - 公开方法 — 输入转发

    /// 由 `PreviewSurfaceCanvas` 在 `isInteractive == true` 时回调；把事件转发给子进程。
    /// 高频事件（mouseMoved / dragged / scrollWheel / keyDown 重复）走 best-effort 不阻塞。
    public func forwardInputEvent(_ event: LumiPreviewFacade.PreviewInputEvent) {
        guard status == .running else { return }
        session.sendInputEventBestEffort(event)
    }

    /// 当前面板是否处于"可交互"状态：session running + 已加载用户视图。
    public var isInteractive: Bool {
        guard status == .running else { return false }
        switch entryStatus {
        case .loaded, .loading, .building: return true
        case .noPreview, .failed: return false
        }
    }

    // MARK: - 公开方法 — 自动构建

    /// 由 Combine 订阅（文件 URL 变化）触发，也可由 View 层直接调用。
    public func setActiveFile(_ url: URL?, sourceText: String?) {
        if Self.verbose {
                    Self.logger.info("\(self.t)📄 设置活跃文件：\(url?.lastPathComponent ?? "nil")，有源码=\(sourceText != nil)")
        }
        let didChangeFile = !Self.sameFile(activeFileURL, url)
        if didChangeFile {
            previewGeneration &+= 1
            clearRenderedPreview()
            entryStatus = .noPreview
            lastBuildInfo = nil
            selectedPreviewIndex = 0
            lastLoadedFingerprint = nil
            entryDebugState = nil
            cursorShape = .arrow
        }
        activeFileURL = url
        latestSourceText = sourceText
        updatePreviewMode(for: url)
        guard previewMode == .swift else {
            resetInlineStateForStaticPreview()
            return
        }
        refreshAvailablePreviews()
        startSessionIfNeededForActiveFile()
        autoBuildIfPossible()
    }

    /// 由 Combine 订阅（保存）触发，也可由 View 层直接调用。
    public func applySaveRevision(sourceText: String?) {
        if Self.verbose {
                    Self.logger.info("\(self.t)💾 应用保存修订，有源码=\(sourceText != nil)")
        }
        latestSourceText = sourceText
        guard previewMode == .swift else { return }
        refreshAvailablePreviews()
        startSessionIfNeededForActiveFile()
        autoBuildIfPossible()
    }

    /// 由 Combine 订阅（内容变化）触发，也可由 View 层直接调用。
    public func updateBufferText(_ sourceText: String?) {
        latestSourceText = sourceText
        guard previewMode == .swift else { return }
        refreshAvailablePreviews()
        startSessionIfNeededForActiveFile()
    }

    public func selectPreview(index: Int) {
        guard Self.shouldSelectPreview(
            index: index,
            currentIndex: selectedPreviewIndex,
            availablePreviewIndexes: availablePreviews.map(\.index),
            previewMode: previewMode
        ) else { return }

        selectedPreviewIndex = index
        lastLoadedFingerprint = nil
        clearRenderedPreview()
        autoBuildIfPossible()
    }

    static func shouldSelectPreview(
        index: Int,
        currentIndex: Int,
        availablePreviewIndexes: [Int],
        previewMode: PreviewMode
    ) -> Bool {
        guard previewMode == .swift else { return false }
        guard index != currentIndex else { return false }
        guard index >= 0 else { return false }
        guard !availablePreviewIndexes.isEmpty else { return true }
        return availablePreviewIndexes.contains(index)
    }

    /// 手动重试预览构建（由 UI 重试按钮触发）。
    public func retryBuild() {
        autoBuildIfPossible()
    }

    public func purgeBuildCaches() {
        if Self.verbose {
            Self.logger.info("\(self.t)🧹 清理 Inline Preview 构建缓存")
        }
        EditorPreviewStorage.installIfNeeded()
        Task { [weak self] in
            await self?.builder.purge()
            EditorPreviewStorage.purgeBuildCaches()
            self?.lastLoadedFingerprint = nil
            self?.lastBuildInfo = nil
            self?.entryDebugState = nil
            self?.refreshCacheSummary()
        }
    }

    public func requestEntryDebugState() {
        guard status == .running else {
            Self.logger.info("\(self.t)📝 requestEntryDebugState skipped: status=\(self.status.description, privacy: .public)")
            return
        }
        guard case .loaded = entryStatus else {
            Self.logger.info("\(self.t)📝 requestEntryDebugState skipped: entryStatus=\(self.entryStatus.description, privacy: .public)")
            return
        }
        isRequestingEntryDebugState = true
        Task { [weak self] in
            do {
                let response = try await self?.session.requestEntryDebugState()
                if Self.verbose {
                Self.logger.info("\(Self.t)📝 requestEntryDebugState response: success=\(response?.success == true, privacy: .public) message=\(response?.message ?? "nil", privacy: .public)")
                }
                if response?.success == false {
                    self?.entryDebugState = response?.message
                }
            } catch {
                if Self.verbose {
                Self.logger.error("\(Self.t)📝 requestEntryDebugState failed: \(error.localizedDescription, privacy: .public)")
                }
                self?.entryDebugState = error.localizedDescription
            }
            self?.isRequestingEntryDebugState = false
        }
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
        guard previewMode == .swift else { return false }
        guard let url = activeFileURL else { return false }
        guard latestSourceText != nil else { return false }
        return url.pathExtension.lowercased() == "swift"
    }

    private func autoBuildIfPossible() {
        let currentStatus = status
        Self.logger.info("\(self.t)📝 autoBuildIfPossible enter: status=\(currentStatus.description, privacy: .public) mode=\(String(describing: self.previewMode), privacy: .public) visible=\(self.isViewVisible, privacy: .public) file=\(self.activeFileURL?.path ?? "nil", privacy: .public) sourceLength=\(self.latestSourceText?.count ?? -1, privacy: .public) canvas=\(self.canvasSize.width, privacy: .public)×\(self.canvasSize.height, privacy: .public) @\(String(format: "%.1f", self.canvasScale), privacy: .public) frames=\(self.receivedFrameCount, privacy: .public) seq=\(self.lastFrameSeq.map(String.init) ?? "nil", privacy: .public)")
        guard currentStatus == .running else {
            if Self.verbose {
                            Self.logger.info("\(self.t)⏭ 跳过 autoBuild — Session 未运行（状态=\(currentStatus.description, privacy: .public)）")
            }
            return
        }
        guard canAutoBuildActiveFile() else {
            Self.logger.info("\(self.t)📝 autoBuildIfPossible skipped: canAutoBuild=false mode=\(String(describing: self.previewMode), privacy: .public) file=\(self.activeFileURL?.path ?? "nil", privacy: .public) hasSource=\(self.latestSourceText != nil, privacy: .public)")
            if isEntryAuto() {
                if Self.verbose {
                                    Self.logger.info("\(Self.t)🔄 autoBuild：无匹配文件，卸载 Dylib")
                }
                clearRenderedPreview()
                Task { [weak self] in
                    _ = try? await self?.session.unloadDylib()
                    self?.entryStatus = .noPreview
                    self?.lastLoadedFingerprint = nil
                    self?.entryDebugState = nil
                }
            }
            return
        }

        guard let url = activeFileURL, let source = latestSourceText else { return }
        EditorPreviewStorage.installIfNeeded()
        let displayName = url.lastPathComponent
        previewGeneration &+= 1
        let generation = previewGeneration
        clearRenderedPreview()
        lastBuildLogURL = nil
        entryStatus = .building(file: displayName)
        Self.logger.info("\(self.t)📝 autoBuild start: file=\(url.path, privacy: .public) previewIndex=\(self.selectedPreviewIndex, privacy: .public) sourceLength=\(source.count, privacy: .public) frameCountBeforeBuild=\(self.receivedFrameCount, privacy: .public) seqBeforeBuild=\(self.lastFrameSeq.map(String.init) ?? "nil", privacy: .public)")
        if Self.verbose {
                    Self.logger.info("\(self.t)🔨 autoBuild：正在构建 \(displayName)")
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.builder.build(
                    fileURL: url,
                    sourceText: source,
                    previewIndex: self.selectedPreviewIndex
                )
                guard self.isCurrentPreviewGeneration(generation, fileURL: url) else { return }
                if Self.verbose {
                                    Self.logger.info("\(Self.t)✅ 构建成功：\(result.dylibURL.path) 指纹=\(result.fingerprint) 标题=\(result.primaryTitle)")
                }
                if Self.verbose {
                Self.logger.info("\(Self.t)📝 build result: dylib=\(result.dylibURL.path, privacy: .public) fingerprint=\(result.fingerprint, privacy: .public) usedCache=\(result.usedCache, privacy: .public) previewCount=\(result.previewCount, privacy: .public) selectedIndex=\(result.selectedPreviewIndex, privacy: .public) title=\(result.primaryTitle, privacy: .public)")
                }
                self.lastBuildInfo = BuildInfo(
                    completedAt: Date(),
                    usedCache: result.usedCache,
                    previewCount: result.previewCount,
                    selectedTitle: result.primaryTitle
                )
                self.refreshCacheSummary()
                self.selectedPreviewIndex = result.selectedPreviewIndex
                if self.lastLoadedFingerprint == result.fingerprint {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)⏭ 指纹相同，跳过加载")
                    }
                    Self.logger.info("\(Self.t)📝 load skipped: same fingerprint=\(result.fingerprint, privacy: .public) entry will be marked loaded without loadDylib; frameCount=\(self.receivedFrameCount, privacy: .public) seq=\(self.lastFrameSeq.map(String.init) ?? "nil", privacy: .public)")
                    self.entryStatus = .loaded(path: result.dylibURL.path, title: result.primaryTitle)
                    return
                }
                self.entryStatus = .loading(path: result.dylibURL.path)
                let frameSeqBeforeLoad = self.lastFrameSeq
                let frameCountBeforeLoad = self.receivedFrameCount
                if Self.verbose {
                Self.logger.info("\(Self.t)📝 loadDylib start: path=\(result.dylibURL.path, privacy: .public) frameCountBeforeLoad=\(frameCountBeforeLoad, privacy: .public) seqBeforeLoad=\(frameSeqBeforeLoad.map(String.init) ?? "nil", privacy: .public) policy=\(self.policy.rawValue, privacy: .public)")
                }
                let loadResponse = try await self.session.loadDylib(path: result.dylibURL.path)
                guard self.isCurrentPreviewGeneration(generation, fileURL: url) else { return }
                if Self.verbose {
                    Self.logger.info("\(Self.t)📥 loadDylib 响应：success=\(loadResponse.success, privacy: .public) message=\(loadResponse.message ?? "nil", privacy: .public)")
                }
                if Self.verbose {
                Self.logger.info("\(Self.t)📝 loadDylib response: success=\(loadResponse.success, privacy: .public) message=\(loadResponse.message ?? "nil", privacy: .public) frameCountAfterResponse=\(self.receivedFrameCount, privacy: .public) seqAfterResponse=\(self.lastFrameSeq.map(String.init) ?? "nil", privacy: .public)")
                }
                guard loadResponse.success else {
                    let message = loadResponse.message ?? "unknown dylib load failure"
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ 构建产物加载失败：\(message)")
                    }
                    self.failEntry(kind: .dylibLoad, message: message)
                    return
                }
                self.lastLoadedFingerprint = result.fingerprint
                self.entryDebugState = nil
                self.entryStatus = .loaded(path: result.dylibURL.path, title: result.primaryTitle)
                if Self.verbose {
                Self.logger.info("\(Self.t)📝 entry marked loaded: title=\(result.primaryTitle, privacy: .public) fingerprint=\(result.fingerprint, privacy: .public) frameCountAtLoaded=\(self.receivedFrameCount, privacy: .public) seqAtLoaded=\(self.lastFrameSeq.map(String.init) ?? "nil", privacy: .public)")
                }
                self.schedulePostLoadFrameDiagnostics(
                    fingerprint: result.fingerprint,
                    title: result.primaryTitle,
                    frameSeqAtLoad: self.lastFrameSeq,
                    frameCountAtLoad: self.receivedFrameCount
                )
                if Self.verbose {
                                    Self.logger.info("\(Self.t)✅ 构建后已加载 Dylib")
                }
            } catch let error as LumiPreviewFacade.PreviewBuilder.BuildError {
                guard self.isCurrentPreviewGeneration(generation, fileURL: url) else { return }
                switch error {
                case .noPreviewFound:
                    if Self.verbose {
                                            Self.logger.warning("\(Self.t)⚠️ 在 \(displayName) 中未找到 #Preview")
                    }
                    if self.isEntryAuto() {
                        _ = try? await self.session.unloadDylib()
                        self.entryStatus = .noPreview
                        self.lastLoadedFingerprint = nil
                        self.entryDebugState = nil
                    } else {
                        self.entryStatus = .noPreview
                    }
                case .sdkResolutionFailed:
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ SDK 解析失败：\(error.localizedDescription)")
                    }
                    self.failEntry(kind: .sdk, message: error.localizedDescription)
                case .swiftcFailed:
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ 编译失败：\(error.localizedDescription)")
                    }
                    self.failEntry(kind: .compile, message: error.localizedDescription)
                case .plannedBuildFailed:
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ 依赖解析/计划构建失败：\(error.localizedDescription)")
                    }
                    self.failEntry(kind: .dependency, message: error.localizedDescription)
                }
            } catch {
                guard self.isCurrentPreviewGeneration(generation, fileURL: url) else { return }
                if Self.verbose {
                                    Self.logger.error("\(Self.t)❌ 构建异常：\(error.localizedDescription)")
                }
                self.failEntry(kind: .unknown, message: error.localizedDescription)
            }
        }
    }

    private func updatePreviewMode(for url: URL?) {
        guard let url else {
            previewMode = .unsupported(nil)
            return
        }

        let ext = url.pathExtension.lowercased()
        if ext == "swift" {
            previewMode = .swift
        } else if ext == "xcassets" {
            previewMode = .xcassets(url)
        } else if Self.imageExtensions.contains(ext) {
            previewMode = .image(url)
        } else if Self.markdownExtensions.contains(ext) {
            previewMode = .markdown(url)
        } else if Self.stringCatalogExtensions.contains(ext) {
            previewMode = .stringCatalog(url)
        } else if Self.jsonExtensions.contains(ext) {
            previewMode = .json(url)
        } else if Self.plistExtensions.contains(ext) {
            previewMode = .plist(url)
        } else if Self.csvExtensions.contains(ext) {
            previewMode = .csv(url)
        } else if Self.htmlExtensions.contains(ext) {
            previewMode = .html(url)
        } else if Self.pdfExtensions.contains(ext) {
            previewMode = .pdf(url)
        } else if Self.docExtensions.contains(ext) {
            previewMode = .doc(url)
        } else {
            previewMode = .unsupported(url)
        }
    }

    private func resetInlineStateForStaticPreview() {
        availablePreviews = []
        selectedPreviewIndex = 0
        entryStatus = .noPreview
        clearRenderedPreview()
        lastLoadedFingerprint = nil
        lastBuildInfo = nil

        if status == .running || status == .starting {
            stopSessionIfNeeded()
        }
    }

    private func startSessionIfNeededForActiveFile() {
        guard isViewVisible else { return }
        guard previewMode == .swift else { return }
        guard let source = latestSourceText, source.contains("#Preview") else { return }
        let currentStatus = status
        guard currentStatus == .idle || currentStatus == .ready || currentStatus == .warming || isFailed(currentStatus) else { return }
        startSession()
    }

    private func stopSessionIfNeeded() {
        if status == .running || status == .starting || status == .warming || status == .ready {
            stopSession(restartIfStillNeeded: true)
        }
    }

    static func shouldRestartAfterStop(
        isViewVisible: Bool,
        previewMode: PreviewMode,
        sourceText: String?
    ) -> Bool {
        guard isViewVisible, previewMode == .swift else { return false }
        return sourceText?.contains("#Preview") == true
    }

    /// 当前 entryStatus 是否对应自动 build 流程。
    private func isEntryAuto() -> Bool {
        switch entryStatus {
        case .building, .loading, .loaded, .failed: return true
        case .noPreview: return false
        }
    }

    private var shouldAcceptFrame: Bool {
        guard previewMode == .swift else { return false }
        switch entryStatus {
        case .loading, .loaded:
            return true
        case .noPreview, .building, .failed:
            return false
        }
    }

    private func clearRenderedPreview() {
        currentFrame = nil
        lastFrameSeq = nil
        receivedFrameCount = 0
        entryDebugState = nil
        cursorShape = .arrow
    }

    private func failEntry(kind: EntryFailureKind, message: String) {
        clearRenderedPreview()
        lastLoadedFingerprint = nil
        entryStatus = .failed(EntryFailure(kind: kind, message: message))

        // 将完整错误日志写入插件专属日志目录
        let logURL = Self.writeBuildLog(
            kind: kind,
            message: message,
            activeFileURL: activeFileURL
        )
        lastBuildLogURL = logURL
    }

    /// 将构建错误日志写入 `build-logs` 目录，返回日志文件 URL。
    private static func writeBuildLog(
        kind: EntryFailureKind,
        message: String,
        activeFileURL: URL?
    ) -> URL? {
        let logsDir = EditorPreviewStorage.buildLogsDirectory
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let fileName = activeFileURL?
            .deletingPathExtension()
            .lastPathComponent
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "unknown"
        let logFileName = "\(fileName)_\(timestamp).log"
        let logURL = logsDir.appendingPathComponent(logFileName)

        let fullLog = """
        # Inline Preview Build Log
        # Time: \(Date().description)
        # File: \(activeFileURL?.path ?? "nil")
        # Error Kind: \(kind.rawValue)
        # ---
        \(message)
        """

        do {
            try FileManager.default.createDirectory(
                at: logsDir,
                withIntermediateDirectories: true
            )
            try fullLog.write(to: logURL, atomically: true, encoding: .utf8)
            if Self.verbose {
                Self.logger.info("\(Self.t)📝 构建日志已写入：\(logURL.path)")
            }
            return logURL
        } catch {
            Self.logger.error("\(Self.t)❌ 写入构建日志失败：\(error.localizedDescription)")
            return nil
        }
    }

    private func isCurrentPreviewGeneration(_ generation: UInt64, fileURL: URL) -> Bool {
        generation == previewGeneration && Self.sameFile(activeFileURL, fileURL)
    }

    private static func sameFile(_ lhs: URL?, _ rhs: URL?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return lhs.standardizedFileURL == rhs.standardizedFileURL
        default:
            return false
        }
    }

    private static func canPrepareInlinePreview(fileURL: URL?, sourceText: String?) -> Bool {
        guard fileURL?.pathExtension.lowercased() == "swift" else { return false }
        return sourceText?.contains("#Preview") == true
    }

    private func refreshAvailablePreviews() {
        guard canAutoBuildActiveFile(),
              let url = activeFileURL,
              let source = latestSourceText else {
            availablePreviews = []
            selectedPreviewIndex = 0
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let summaries = await self.builder.discoverPreviews(fileURL: url, sourceText: source)
            guard Self.sameFile(self.activeFileURL, url), self.latestSourceText == source else { return }
            self.availablePreviews = summaries
            if summaries.isEmpty {
                self.selectedPreviewIndex = 0
            } else if !summaries.contains(where: { $0.index == self.selectedPreviewIndex }) {
                self.selectedPreviewIndex = summaries[0].index
            }
        }
    }

    // MARK: - 私有

    private func warmupSessionIfPossible() {
        guard status == .idle else { return }
        status = .warming
        warmupTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.session.start()
                guard !Task.isCancelled else {
                    await self.session.stop()
                    return
                }
                if self.status == .warming {
                    self.status = .ready
                }
                if Self.verbose {
                    Self.logger.info("\(Self.t)✅ Inline Preview host 预热完成")
                }
            } catch {
                guard !Task.isCancelled else { return }
                if Self.verbose {
                    Self.logger.warning("\(Self.t)⚠️ Inline Preview host 预热失败，将在正式启动时重试：\(error.localizedDescription)")
                }
                if self.status == .warming {
                    self.status = .idle
                }
            }
        }
    }

    private func refreshCacheSummary() {
        cacheSummaryTask?.cancel()
        cacheSummaryTask = Task { [weak self] in
            let summary = await Task.detached(priority: .utility) {
                EditorPreviewStorage.refreshCacheSummary()
            }.value

            guard !Task.isCancelled else { return }
            self?.cacheSummary = summary
            self?.cacheSummaryTask = nil
        }
    }

    private func wireSessionCallbacks() {
        session.onFrame = { [weak self] frame in
            Task { @MainActor in
                guard let self else { return }
                guard self.shouldAcceptFrame else { return }
                self.lastFrameSeq = frame.seq
                self.receivedFrameCount &+= 1
                self.currentFrame = frame
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
                self?.currentFrame = nil
                self?.lastLoadedFingerprint = nil
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
                self?.currentFrame = nil
                self?.entryStatus = .noPreview
                self?.lastLoadedFingerprint = nil
                self?.entryDebugState = nil
                self?.cursorShape = .arrow
            }
        }
        session.onEntryLoaded = { [weak self] success, message in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    if Self.verbose {
                                            Self.logger.info("\(Self.t)✅ onEntryLoaded 成功：\(message ?? "nil")")
                    }
                    // loadDylib 的 await 路径带有 generation 校验；这个回调没有来源标识，
                    // 只作为诊断信号，避免旧 dylib 回调覆盖当前文件/构建状态。
                    if case .loaded = self.entryStatus {
                        self.entryDebugState = nil
                    }
                } else {
                    if Self.verbose {
                                            Self.logger.error("\(Self.t)❌ onEntryLoaded 失败：\(message ?? "nil")")
                    }
                }
            }
        }
        session.onEntryDebugState = { [weak self] state in
            Task { @MainActor in
                if Self.verbose {
                    Self.logger.info("\(Self.t)🩺 收到 entry debug state：\(state, privacy: .public)")
                }
                self?.entryDebugState = state
            }
        }
        session.onCursorChanged = { [weak self] shape in
            Task { @MainActor in
                self?.cursorShape = shape
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
            do {
                let response = try await self?.session.resize(width: w, height: h, scale: s)
                if Self.verbose {
                    Self.logger.info("\(Self.t)📐 resize 响应：success=\(response?.success == true, privacy: .public) message=\(response?.message ?? "nil", privacy: .public)")
                }
            } catch {
                if Self.verbose {
                    Self.logger.error("\(Self.t)❌ resize 失败：\(error.localizedDescription)")
                }
            }
        }
    }

    private func schedulePostLoadFrameDiagnostics(
        fingerprint: String,
        title: String,
        frameSeqAtLoad: UInt64?,
        frameCountAtLoad: UInt64
    ) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self else { return }
            guard case .loaded = self.entryStatus else { return }
            guard self.lastLoadedFingerprint == fingerprint || fingerprint == "callback" else { return }

            let currentSeq = self.lastFrameSeq
            let currentCount = self.receivedFrameCount
            if currentCount == frameCountAtLoad {
                let seqText = currentSeq.map(String.init) ?? "nil"
                if Self.verbose {
                Self.logger.error("\(Self.t)📝 Inline Preview 诊断：dylib 已加载但 3s 内没有新帧。title=\(title, privacy: .public) fingerprint=\(fingerprint, privacy: .public) seqAtLoad=\(frameSeqAtLoad.map(String.init) ?? "nil", privacy: .public) currentSeq=\(seqText, privacy: .public) status=\(self.status.description, privacy: .public) policy=\(self.policy.rawValue, privacy: .public) canvas=\(self.canvasSize.width, privacy: .public)×\(self.canvasSize.height, privacy: .public) @\(String(format: "%.1f", self.canvasScale), privacy: .public)")
                }
                self.requestEntryDebugState()
            } else {
                if Self.verbose {
                Self.logger.info("\(Self.t)📝 Inline Preview 诊断：dylib 加载后已收到新帧。title=\(title, privacy: .public) framesDelta=\(currentCount - frameCountAtLoad, privacy: .public) seq=\(currentSeq.map(String.init) ?? "nil", privacy: .public) policy=\(self.policy.rawValue, privacy: .public)")
                }
            }
        }
    }

    private func isFailed(_ status: SessionStatus) -> Bool {
        if case .failed = status { return true }
        return false
    }

    public func cleanCurrentStringCatalog(
        fileURL: URL?,
        sourceText: String?,
        editorService: EditorService
    ) throws -> Int {
        guard let fileURL, fileURL.pathExtension.lowercased() == "xcstrings" else {
            return 0
        }

        let source: String
        if let sourceText {
            source = sourceText
        } else {
            source = try Self.stringCatalogSource(from: fileURL)
        }
        let result = try StringCatalogCleaner.removingStaleEntries(from: source)
        guard result.removedCount > 0 else {
            return 0
        }

        if editorService.files.currentFileURL?.standardizedFileURL == fileURL.standardizedFileURL {
            _ = editorService.files.replaceCurrentDocumentText(
                result.source,
                reason: "string_catalog_remove_stale_entries"
            )
            editorService.files.saveNow()
        } else {
            try result.source.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return result.removedCount
    }

    public func removeStaleStringCatalogEntry(
        key: String,
        fileURL: URL?,
        sourceText: String?,
        editorService: EditorService
    ) throws -> Bool {
        guard let fileURL, fileURL.pathExtension.lowercased() == "xcstrings" else {
            return false
        }

        let source: String
        if let sourceText {
            source = sourceText
        } else {
            source = try Self.stringCatalogSource(from: fileURL)
        }
        let result = try StringCatalogCleaner.removingStaleEntry(withKey: key, from: source)
        guard result.removedCount > 0 else {
            return false
        }

        if editorService.files.currentFileURL?.standardizedFileURL == fileURL.standardizedFileURL {
            _ = editorService.files.replaceCurrentDocumentText(
                result.source,
                reason: "string_catalog_remove_stale_entry"
            )
            editorService.files.saveNow()
        } else {
            try result.source.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        return true
    }

    func cleanProjectStringCatalogs(
        projectRootPath: String,
        currentFileURL: URL?,
        currentSourceText: String?,
        editorService: EditorService
    ) async throws -> StringCatalogProjectCleanSummary {
        let rootURL = URL(fileURLWithPath: projectRootPath)
        let currentStandardizedURL = currentFileURL?.standardizedFileURL
        let cleanResult = try await Task.detached(priority: .userInitiated) {
            try Self.cleanStringCatalogs(
                under: rootURL,
                currentFileURL: currentStandardizedURL,
                currentSourceText: currentSourceText
            )
        }.value

        if let currentCleanedSource = cleanResult.currentCleanedSource,
           let currentStandardizedURL,
           editorService.files.currentFileURL?.standardizedFileURL == currentStandardizedURL {
            _ = editorService.files.replaceCurrentDocumentText(
                currentCleanedSource,
                reason: "string_catalog_remove_project_stale_entries"
            )
            editorService.files.saveNow()
        }

        return cleanResult.summary
    }

    private struct StringCatalogProjectCleanResult: Sendable {
        let summary: StringCatalogProjectCleanSummary
        let currentCleanedSource: String?
    }

    private nonisolated static func cleanStringCatalogs(
        under rootURL: URL,
        currentFileURL: URL?,
        currentSourceText: String?
    ) throws -> StringCatalogProjectCleanResult {
        let fileManager = FileManager.default
        let skipDirectoryNames: Set<String> = [
            ".build", ".git", ".swiftpm", "DerivedData", "node_modules"
        ]
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return StringCatalogProjectCleanResult(
                summary: StringCatalogProjectCleanSummary(
                    scannedFileCount: 0,
                    changedFileCount: 0,
                    removedEntryCount: 0
                ),
                currentCleanedSource: nil
            )
        }

        var scannedFileCount = 0
        var changedFileCount = 0
        var removedEntryCount = 0
        var currentCleanedSource: String?

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey])
            if resourceValues.isDirectory == true {
                if skipDirectoryNames.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard resourceValues.isRegularFile == true,
                  fileURL.pathExtension.lowercased() == "xcstrings" else {
                continue
            }

            scannedFileCount += 1
            let standardizedURL = fileURL.standardizedFileURL
            let source: String
            if standardizedURL == currentFileURL, let currentSourceText {
                source = currentSourceText
            } else {
                source = try stringCatalogSource(from: fileURL)
            }

            let result = try StringCatalogCleaner.removingStaleEntries(from: source)
            guard result.removedCount > 0 else { continue }

            try result.source.write(to: fileURL, atomically: true, encoding: .utf8)
            if standardizedURL == currentFileURL {
                currentCleanedSource = result.source
            }
            changedFileCount += 1
            removedEntryCount += result.removedCount
        }

        return StringCatalogProjectCleanResult(
            summary: StringCatalogProjectCleanSummary(
                scannedFileCount: scannedFileCount,
                changedFileCount: changedFileCount,
                removedEntryCount: removedEntryCount
            ),
            currentCleanedSource: currentCleanedSource
        )
    }

    nonisolated static func stringCatalogSource(from fileURL: URL) throws -> String {
        var detectedEncoding = String.Encoding.utf8
        return try String(contentsOf: fileURL, usedEncoding: &detectedEncoding)
    }

    // MARK: - 截图

    /// 从当前 canvas 的 surfaceView 中截取图像。
    /// 返回截取的 NSImage，调用方负责保存或复制到剪贴板。
    public func takeScreenshot(from nsView: NSView?) -> NSImage? {
        guard let nsView else {
            if Self.verbose {
                Self.logger.warning("\(self.t)📸 takeScreenshot: nsView 为 nil")
            }
            return nil
        }

        // 尝试找到 PreviewSurfaceView
        guard let surfaceView = findPreviewSurfaceView(in: nsView) else {
            if Self.verbose {
                Self.logger.warning("\(self.t)📸 takeScreenshot: 未找到 PreviewSurfaceView")
            }
            return nil
        }

        let bounds = surfaceView.bounds
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        // 使用 bitmapImageRepForCachingDisplay 截取视图内容
        guard let bitmapRep = surfaceView.bitmapImageRepForCachingDisplay(in: bounds) else {
            return nil
        }
        surfaceView.cacheDisplay(in: bounds, to: bitmapRep)
        let image = NSImage()
        image.addRepresentation(bitmapRep)
        image.size = bounds.size
        return image
    }

    /// 递归查找 PreviewSurfaceView。
    private func findPreviewSurfaceView(in view: NSView) -> LumiPreviewFacade.PreviewSurfaceView? {
        if let surfaceView = view as? LumiPreviewFacade.PreviewSurfaceView {
            return surfaceView
        }
        for subview in view.subviews {
            if let found = findPreviewSurfaceView(in: subview) {
                return found
            }
        }
        return nil
    }

    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "tiff", "tif", "bmp", "webp",
        "svg", "icns", "ico", "heic", "heif"
    ]
    private static let markdownExtensions: Set<String> = ["md", "markdown"]
    private static let stringCatalogExtensions: Set<String> = ["xcstrings"]
    private static let jsonExtensions: Set<String> = ["json", "jsonl"]
    private static let plistExtensions: Set<String> = ["plist"]
    private static let csvExtensions: Set<String> = ["csv", "tsv"]
    private static let htmlExtensions: Set<String> = ["html", "htm"]
    private static let pdfExtensions: Set<String> = ["pdf"]
    private static let docExtensions: Set<String> = ["doc", "docx"]
}
