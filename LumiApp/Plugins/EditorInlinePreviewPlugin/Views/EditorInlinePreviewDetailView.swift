import AppKit
import LumiInlinePreviewKit
import MagicAlert
import MagicKit
import os
import SwiftUI

/// 内嵌预览插件的底部面板内容视图。
///
/// 提供以下功能：
/// - **Start / Stop Stream**：启动 `LumiInlinePreviewHostApp` 子进程，订阅帧流，实时显示预览。
/// - **Load Dylib…**：手动挑选一个用户编译产出的预览 dylib，让子进程 `dlopen`
///   并把其 `lumi_preview_make_nsview` 导出的 `NSView` 挂为 previewView。
/// - 自动构建：打开 Swift 文件并保存时自动扫描 `#Preview`，编译并加载。
struct EditorInlinePreviewDetailView: View, SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.view"
    )
    nonisolated static let emoji = "👁"
    nonisolated static let verbose: Bool = true

    @EnvironmentObject private var editorVM: EditorVM
    @StateObject private var viewModel = EditorInlinePreviewViewModel()
    @StateObject private var automationState = InlinePreviewAutomationState.shared

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            canvasArea
        }
        .onAppear {
            if Self.verbose {
                Self.logger.info("\(self.t)📺 视图出现 — 当前文件=\(currentFileURL?.lastPathComponent ?? "nil")")
            }
            // 订阅 EditorService（幂等，内部有 Combine 订阅，多次调用会重复订阅，所以只调一次）
            viewModel.wireEditorService(editorVM.service)

            // 消费 AutomationController 可能在 View 出现之前就写入的 pending sessionAction。
            if let pendingAction = automationState.sessionAction {
                automationState.sessionAction = nil
                switch pendingAction {
                case .start:
                    if Self.verbose {
                        Self.logger.info("\(self.t)🤖 onAppear 消费 pending sessionAction=.start")
                    }
                    viewModel.startSession()
                case .stop:
                    if Self.verbose {
                        Self.logger.info("\(self.t)🤖 onAppear 消费 pending sessionAction=.stop")
                    }
                    viewModel.stopSession()
                }
            }
        }
        .onChange(of: currentFileURL) { _, newValue in
            if Self.verbose {
                Self.logger.info("\(self.t)📄 currentFileURL 变更 → \(newValue?.lastPathComponent ?? "nil")")
            }
            viewModel.setActiveFile(newValue, sourceText: sourceText)
        }
        .onChange(of: editorVM.service.saveRevision) { _, _ in
            if Self.verbose {
                Self.logger.info("\(self.t)💾 saveRevision 变更")
            }
            viewModel.applySaveRevision(sourceText: sourceText)
        }
        .onChange(of: editorVM.service.contentRevision) { _, _ in
            viewModel.updateBufferText(sourceText)
        }
        // 监听自动化测试动作
        .onAutomationAction { action, payload in
            switch action {
            case "inline_preview.start_stream", "inline_preview.startStream":
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化：收到 start_stream 动作")
                }
                alert_info("自动化测试：启动预览流")
                viewModel.startSession()
            case "inline_preview.stop_stream", "inline_preview.stopStream":
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化：收到 stop_stream 动作")
                }
                alert_info("自动化测试：停止预览流")
                viewModel.stopSession()
            default:
                break
            }
        }
        // 监听自动化共享状态
        .onChange(of: automationState.sessionAction) { oldAction, newAction in
            guard let newAction else { return }
            automationState.sessionAction = nil
            switch newAction {
            case .start:
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化状态：消费 sessionAction=.start")
                }
                alert_info("自动化测试：启动预览流")
                viewModel.startSession()
            case .stop:
                if Self.verbose {
                    Self.logger.info("\(self.t)🤖 自动化状态：消费 sessionAction=.stop")
                }
                alert_info("自动化测试：停止预览流")
                viewModel.stopSession()
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            sessionToggleButton

            Divider().frame(height: 16)

            entryControls

            Spacer()

            entryStatusBadge

            statusBadge

            if let frame = viewModel.currentFrame {
                Text("seq \(frame.seq) · \(frame.width)×\(frame.height) @\(String(format: "%.0fx", frame.scale))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var entryControls: some View {
        Button {
            pickDylibAndLoad()
        } label: {
            Label("Load Dylib…", systemImage: "tray.and.arrow.down.fill")
        }
        .buttonStyle(.borderless)
        .disabled(viewModel.status != .running)
        .help("Pick a .dylib that exports lumi_preview_make_nsview and let the subprocess render it.")

        if isEntryActive {
            Button {
                viewModel.unloadDylib()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.status != .running)
            .help("Unload the user dylib.")
        }
    }

    @ViewBuilder
    private var entryStatusBadge: some View {
        switch viewModel.entryStatus {
        case .noPreview:
            EmptyView()
        case let .building(file):
            HStack(spacing: 4) {
                ProgressView().controlSize(.small)
                Text("building \(file)")
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        case let .loading(path):
            Text("loading \((path as NSString).lastPathComponent)")
                .font(.caption)
                .foregroundStyle(.orange)
                .lineLimit(1)
                .truncationMode(.middle)
        case let .loaded(_, title):
            Text("entry · \(title)")
                .font(.caption)
                .foregroundStyle(.green)
                .lineLimit(1)
                .truncationMode(.middle)
        case let .failed(message):
            Text("entry failed: \(message)")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private var isEntryActive: Bool {
        switch viewModel.entryStatus {
        case .noPreview: return false
        case .building, .loading, .loaded, .failed: return true
        }
    }

    private func pickDylibAndLoad() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.message = "Select a preview .dylib that exports lumi_preview_make_nsview"
        panel.prompt = "Load"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.loadDylib(at: url)
        }
    }

    private var sessionToggleButton: some View {
        Group {
            switch viewModel.status {
            case .idle, .failed:
                Button {
                    viewModel.startSession()
                } label: {
                    Label("Start Stream", systemImage: "play.fill")
                }
                .buttonStyle(.borderless)
            case .starting:
                Button {} label: {
                    Label("Starting", systemImage: "hourglass")
                }
                .disabled(true)
                .buttonStyle(.borderless)
            case .running:
                Button {
                    viewModel.stopSession()
                } label: {
                    Label("Stop Stream", systemImage: "stop.fill")
                }
                .buttonStyle(.borderless)
            case .stopping:
                Button {} label: {
                    Label("Stopping", systemImage: "hourglass")
                }
                .disabled(true)
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch viewModel.status {
        case .idle:
            EmptyView()
        case .starting:
            Text("starting").font(.caption).foregroundStyle(.orange)
        case .running:
            Text("running · \(viewModel.policy.rawValue)").font(.caption).foregroundStyle(.green)
        case .stopping:
            Text("stopping").font(.caption).foregroundStyle(.orange)
        case let .failed(message):
            Text("failed: \(message)")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: - Canvas

    @ViewBuilder
    private var canvasArea: some View {
        let hasFrame = viewModel.currentFrame != nil
        ZStack {
            // 底层网格背景
            EditorInlinePreviewBoardGrid()

            if !hasFrame {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("Click \"Start Stream\" to launch the preview subprocess. Open a Swift file with a `#Preview` and press ⌘S to auto-build & render it.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            LumiInlinePreviewFacade.PreviewSurfaceCanvas(
                surfaceID: viewModel.currentFrame?.surfaceID,
                isInteractive: viewModel.isInteractive,
                onSizeChange: { size, scale in
                    viewModel.canvasDidResize(size, scale: scale)
                },
                onInputEvent: { event in
                    viewModel.forwardInputEvent(event)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(hasFrame ? Color.clear : Color.black.opacity(0.01))
        }
    }
}
