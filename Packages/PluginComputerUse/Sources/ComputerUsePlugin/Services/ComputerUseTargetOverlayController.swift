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
    /// 目标窗口的 `CGWindowID`；AX 路径拿不到时为 `nil`。
    private var targetWindowID: CGWindowID?
    /// 目标窗口所属进程。
    private var targetProcessIdentifier: pid_t?

    /// 一次遮罩的目标描述。
    struct Target: Equatable {
        /// 目标窗口的 Quartz 矩形。
        let quartzRect: CGRect
        /// 目标应用显示名。
        let applicationName: String
        /// 遮罩强度。
        let intensity: ComputerUseTargetOverlayIntensity
        /// 目标窗口的 `CGWindowID`；AX 路径拿不到时为 `nil`。
        let windowID: CGWindowID?
        /// 目标窗口所属进程；用于在没有窗口 ID 时近似匹配遮挡关系。
        let processIdentifier: pid_t?
    }

    private init() {}

    // MARK: - 生命周期

    /// 显示遮罩并开始跟随目标窗口。
    ///
    /// - Parameters:
    ///   - target: 目标描述。
    ///   - windowElement: 用于跟随的 AX 窗口元素；为 `nil` 时只按初始矩形显示。
    ///   - processIdentifier: `windowElement` 所属进程，跟随时用于建立 AX 观察。
    func begin(
        _ target: Target,
        windowElement: AXUIElement? = nil,
        processIdentifier: pid_t? = nil
    ) {
        lingerTask?.cancel()
        lingerTask = nil
        model.applicationName = target.applicationName
        model.intensity = target.intensity
        model.isFading = false
        targetWindowID = target.windowID
        targetProcessIdentifier = target.processIdentifier ?? processIdentifier

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
        // 可见区域必须在面板显示前算好：否则会先闪出一块盖住遮挡者的色调。
        applyVisibleRegions(for: target.quartzRect)
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
                self.follow(
                    quartzRect: rect,
                    currentPanelFrame: self.panel?.frame,
                    setPanelFrame: { [weak self] frame in
                        self?.panel?.setFrame(frame, display: true)
                    },
                    refreshVisibleRegions: { [weak self] rect in
                        self?.applyVisibleRegions(for: rect)
                    }
                )
            }
        }
    }

    private func stopFollowing() {
        followTask?.cancel()
        followTask = nil
        geometryObserver?.stop()
        geometryObserver = nil
    }

    /// 执行一次跟随轮询：移动面板与重算可见区域彼此独立。
    ///
    /// 目标窗口本身不动时，遮挡它的其他窗口仍可能移动、关闭或改变层级，
    /// 所以可见区域必须每次轮询都重算；只有矩形变化时才需要移动面板，
    /// 避免无意义的重绘。
    func follow(
        quartzRect: CGRect,
        currentPanelFrame: CGRect?,
        setPanelFrame: (CGRect) -> Void,
        refreshVisibleRegions: (CGRect) -> Void
    ) {
        guard let appKitRect = ScreenCoordinateConverter.appKitRect(fromQuartz: quartzRect) else { return }
        if appKitRect != currentPanelFrame {
            setPanelFrame(appKitRect)
        }
        refreshVisibleRegions(quartzRect)
    }

    /// 重新计算目标窗口的可见区域，并同步到视图模型。
    ///
    /// 遮罩只覆盖目标窗口**真正露出来**的部分。被别的窗口挡住的部分
    /// 属于遮挡者，画上色调与角标会让用户误以为 Lumi 在操作那个窗口。
    private func applyVisibleRegions(for quartzRect: CGRect) {
        guard let regions = ComputerUseWindowVisibility.visibleRegions(
            target: quartzRect,
            targetWindowID: targetWindowID,
            processIdentifier: targetProcessIdentifier,
            excludingWindowID: overlayWindowID
        ) else {
            // 无法定位目标窗口（可能在别的 Space、已最小化）。
            // 此时不能假设它完全可见，否则遮罩会盖到遮挡者身上。
            model.visibleRegions = []
            model.badgeRegion = nil
            return
        }
        let localRegions = regions.map { region in
            CGRect(
                x: region.minX - quartzRect.minX,
                y: region.minY - quartzRect.minY,
                width: region.width,
                height: region.height
            )
        }
        model.visibleRegions = localRegions
        model.badgeRegion = badgeRegion(in: localRegions)
    }

    /// 遮罩面板自己的 `CGWindowID`。
    ///
    /// 面板层级是 `.screenSaver` 且覆盖整个目标，必须从遮挡者里排除，
    /// 否则每次重算都会把自己的面板当作遮挡物，把可见区域扣成空。
    private var overlayWindowID: CGWindowID? {
        guard let number = panel?.windowNumber,
              number > 0,
              number <= Int(UInt32.max) else {
            return nil
        }
        return CGWindowID(number)
    }

    /// 挑选安放角标的区域。
    ///
    /// 角标优先落在最大的可见区域的左上角——那通常是窗口标题栏的位置，
    /// 用户视线第一落点。若最大区域太窄放不下角标，则退而选择第一个
    /// 放得下的区域；都放不下就只保留色调，不画角标。
    private func badgeRegion(in regions: [CGRect]) -> CGRect? {
        let badgeSize = CGSize(width: 200, height: 28)
        for region in regions {
            guard region.width >= badgeSize.width, region.height >= badgeSize.height else { continue }
            return region
        }
        return nil
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
