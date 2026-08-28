import AppKit
import SwiftUI

/// 录制指示器的可观察状态。
@MainActor
final class RecordingIndicatorModel: ObservableObject {
    @Published var description: String = ""
    @Published var elapsedSeconds: Int = 0
    @Published var isStopping = false

    func formattedElapsed() -> String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    func stop() {
        guard !isStopping else { return }
        isStopping = true
        Task {
            _ = try? await RecordingSessionManager.shared.stop()
            isStopping = false
        }
    }
}

/// 药丸内容：🔴 + 录制描述 + 计时 + 停止按钮。
struct RecordingIndicatorContent: View {
    @ObservedObject var model: RecordingIndicatorModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .opacity(0.9)
            Text("\(model.description) · \(model.formattedElapsed())")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Button {
                model.stop()
            } label: {
                Text(model.isStopping ? "…" : "Stop")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
            .disabled(model.isStopping)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
    }
}

/// 系统级置顶的录制指示器窗口。对照 `ChatScreenshotOverlayWindow` 的 NSPanel 配置，
/// 但更小、不抢焦点（`.nonactivatingPanel` + `level = .statusBar`）。
@MainActor
final class RecordingIndicatorWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = false
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// 控制指示器窗口的显示/更新/隐藏，由 `RecordingSessionManager` 驱动。
@MainActor
final class RecordingIndicatorController {
    static let shared = RecordingIndicatorController()

    private var window: RecordingIndicatorWindow?
    private let model = RecordingIndicatorModel()

    private init() {}

    func show(description: String) {
        model.description = description
        model.elapsedSeconds = 0
        model.isStopping = false

        let window = self.window ?? RecordingIndicatorWindow()
        let hosting = NSHostingView(rootView: RecordingIndicatorContent(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = hosting
        self.window = window

        // 按内容自适应尺寸后，定位于主屏顶部居中。
        let fitSize = hosting.fittingSize
        let width = max(fitSize.width + 8, 200)
        let height = max(fitSize.height + 8, 36)
        setFrame(width: width, height: height)
        if !window.isVisible {
            window.orderFrontRegardless()
        }
    }

    func update(elapsed seconds: Int) {
        model.elapsedSeconds = seconds
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func setFrame(width: CGFloat, height: CGFloat) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let x = frame.midX - width / 2
        let y = frame.maxY - height - 12
        window?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
