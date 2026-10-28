import AppKit
import Foundation
import LumiLoggingKit
import SwiftUI
import os

/// 目标窗口提示遮罩的控制器。
///
/// 职责：
/// 1. 在目标窗口上显示遮罩 + 角标，让用户明确知道「这是 Lumi 在操作」；
/// 2. 跟随目标窗口的移动与缩放；
/// 3. 在操作结束后保留一段时间再淡出，避免一闪而过导致用户根本没看见。
///
/// - Note: 遮罩是**纯视觉**提示，不参与输入分发
///   （面板的 `ignoresMouseEvents` 恒为 `true`）。
@MainActor
final class ComputerUseTargetOverlayController: SuperLog {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.computer-use",
        category: "ComputerUseTargetOverlay"
    )
    nonisolated static let verbose = false

    /// 遮罩唯一的实例。桌面上的遮罩必须全局唯一，
    /// 否则多个操作会叠出多层遮罩，用户无法分辨。
    static let shared = ComputerUseTargetOverlayController()

    /// 操作结束后角标继续停留的时长。
    ///
    /// 太短会让提示一闪而过，用户来不及察觉；太长又会持续干扰。
    nonisolated static let lingerDuration: TimeInterval = 2.5

    /// 跟随目标窗口的轮询间隔。
    ///
    /// AX 的窗口移动通知在部分应用上不可靠（实测有的应用不注册该通知），
    /// 因此跟随采用「通知 + 轮询」双保险：通知到达时立即刷新，
    /// 轮询兜底保证遮罩不会长期错位。
    nonisolated static let followInterval: Duration = .milliseconds(250)

    private var panel: ComputerUseTargetOverlayPanel?
    private let model = ComputerUseTargetOverlayModel()
    private var geometryObserver: ComputerUseWindowGeometryObserver?
    private var lingerTask: Task<Void, Never>?
    private var followTask: Task<Void, Never>?

    /// 一次遮罩的目标描述。
    struct Target: Equatable {
        /// 目标窗口的 Quartz 矩形。
        let quartzRect: CGRect
        /// 目标应用显示名。
        let applicationName: String
        /// 遮罩强度。
        let intensity: ComputerUseTargetOverlayIntensity
    }

    private init() {}

    // MARK: - 生命周期

    /// 显示遮罩并开始跟随目标窗口。
    ///
    /// - Parameters:
    ///   - target: 目标描述。
    ///   - windowElement: 用于跟随的 AX 窗口元素；为 `nil` 时只按初始矩形显示。
    ///   - processIdentifier: `windowElement` 所属进程，跟随时用于建立 AX 观察。
    func begin(_ target: Target, windowElement: AXUIElement? = nil, processIdentifier: pid_t? = nil) {
        lingerTask?.cancel()
        lingerTask = nil
        model.applicationName = target.applicationName
        model.intensity = target.intensity
        model.isFading = false

        guard let appKitRect = ScreenCoordinateConverter.appKitRect(fromQuartz: target.quartzRect),
              appKitRect.width >= 40, appKitRect.height >= 40 else {
            if Self.verbose {
                Self.logger.info("\(Self.t)跳过遮罩：无法定位目标窗口矩形")
            }
            return
        }

        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.setFrame(appKitRect, display: true)
        panel.orderFrontRegardless()

        if let windowElement, let processIdentifier {
            let observer = ComputerUseWindowGeometryObserver()
            observer.start(processIdentifier: processIdentifier, windowElement: windowElement)
            geometryObserver = observer
            startFollowing()
        }
    }

    /// 结束遮罩：角标停留一段时间后淡出。
    ///
    /// 不立即消失是刻意的设计：AX 操作往往转瞬即逝，立即消失会让用户
    /// 完全无法察觉。停留 + 淡出让提示既可见又不打扰。
    func end() {
        stopFollowing()
        lingerTask?.cancel()
        lingerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.lingerDuration))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    /// 立即移除遮罩（插件卸载、用户强制停止等场景）。
    func removeImmediately() {
        lingerTask?.cancel()
        lingerTask = nil
        stopFollowing()
        panel?.orderOut(nil)
    }

    // MARK: - 私有

    private func makePanel() -> ComputerUseTargetOverlayPanel {
        let panel = ComputerUseTargetOverlayPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 200)
        )
        let hosting = NSHostingView(rootView: ComputerUseTargetOverlayView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hosting
        return panel
    }

    /// 轮询目标窗口几何，把遮罩挪到新位置。
    private func startFollowing() {
        followTask?.cancel()
        followTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.followInterval)
                guard !Task.isCancelled else { return }
                guard let self, let rect = self.geometryObserver?.currentRect() else { continue }
                self.follow(rect)
            }
        }
    }

    private func stopFollowing() {
        followTask?.cancel()
        followTask = nil
        geometryObserver?.stop()
        geometryObserver = nil
    }

    /// 目标窗口移动或缩放后，把遮罩挪到新位置。
    private func follow(_ quartzRect: CGRect) {
        guard let appKitRect = ScreenCoordinateConverter.appKitRect(fromQuartz: quartzRect) else { return }
        guard appKitRect != panel?.frame else { return }
        panel?.setFrame(appKitRect, display: true)
    }

    private func fadeOut() {
        model.isFading = true
        let panel = self.panel
        lingerTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
            self?.model.isFading = false
        }
    }
}
