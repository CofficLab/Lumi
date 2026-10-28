import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// 目标窗口的几何信息。
///
/// 坐标系说明（全插件统一）：**Quartz 桌面坐标**，原点在桌面左上角、y 向下。
///
/// - `CGWindowListCopyWindowInfo` 直接返回这个坐标系。
/// - AX 的 `kAXPositionAttribute` 同样返回这个坐标系（已实测与 Quartz 完全一致）。
///
/// 两者一致这一点很重要：它让 AX 路径与原生输入路径可以共用同一套几何解析，
/// 不需要为两条路径各写一套坐标换算。
struct ComputerUseTargetGeometry: Equatable {
    /// Quartz 坐标下的窗口矩形。
    let quartzRect: CGRect
    /// 所属进程。
    let processIdentifier: pid_t
    /// 所属应用显示名。
    let applicationName: String

    /// 窗口在 AppKit 坐标系（原点在主屏左下、y 向上）中的矩形。
    ///
    /// 转换必须按**窗口所在的那块屏幕**翻转，不能用主屏高度：
    /// 多屏且副屏在主屏上方/下方时，用主屏高度会得到纵向错位的矩形。
    var appKitRect: CGRect? {
        ScreenCoordinateConverter.appKitRect(fromQuartz: quartzRect)
    }
}

/// Quartz 与 AppKit 坐标系之间的换算。
///
/// - Note: Quartz 坐标以整个桌面左上角为原点，y 向下；AppKit 坐标以主屏
///   左下角为原点，y 向上。两者的换算依赖于**所属屏幕**在桌面中的位置。
enum ScreenCoordinateConverter {
    /// 把 Quartz 矩形转换为 AppKit 矩形。
    ///
    /// - Returns: 窗口所在屏幕无法确定时返回 `nil`（此时不能安全地画遮罩）。
    static func appKitRect(fromQuartz quartzRect: CGRect) -> CGRect? {
        guard quartzRect.width > 0, quartzRect.height > 0 else { return nil }
        for screen in NSScreen.screens {
            let screenFrame = screen.frame
            // 屏幕在 AppKit 坐标里的矩形，翻转成 Quartz 坐标用于命中判断。
            let screenQuartz = CGRect(
                x: screenFrame.minX,
                y: screenFrame.maxY - screenFrame.height,
                width: screenFrame.width,
                height: screenFrame.height
            )
            guard quartzRect.intersects(screenQuartz) else { continue }
            // 窗口顶边相对该屏幕顶部的偏移，换算回 AppKit 的 y。
            let topOffsetInQuartz = quartzRect.minY - screenQuartz.minY
            let topInAppKit = screenFrame.maxY - topOffsetInQuartz
            return CGRect(
                x: quartzRect.minX,
                y: topInAppKit - quartzRect.height,
                width: quartzRect.width,
                height: quartzRect.height
            )
        }
        return nil
    }
}

/// 目标窗口几何的查询入口。
///
/// 提供两种定位方式：
/// 1. `quartzRect(forWindowID:)`——按 CGWindowID 查（原生输入路径用，窗口已知）；
/// 2. `axWindowRect(of:)`——按 AX 元素反查所属窗口（AX 路径用，元素已知）。
enum ComputerUseTargetGeometryProvider {
    // MARK: - Quartz 查询

    /// 按 CGWindowID 查询窗口几何。
    ///
    /// - Returns: 窗口不可见或已关闭时返回 `nil`。
    static func quartzRect(forWindowID windowID: CGWindowID) -> CGRect? {
        guard let raw = windowInfo(forWindowID: windowID) else { return nil }
        guard let bounds = raw[kCGWindowBounds] as? NSDictionary,
              let rect = CGRect(dictionaryRepresentation: bounds) else { return nil }
        return rect
    }

    /// 按进程与窗口标题查询窗口几何。
    ///
    /// AX 路径拿不到 CGWindowID，只能用「进程 + 标题」近似匹配；
    /// 同一应用有多个同名窗口时取面积最大的一个（主窗口）。
    static func quartzRect(processIdentifier: pid_t, windowTitle: String) -> CGRect? {
        let normalized = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else { return nil }

        var candidates: [CGRect] = []
        for raw in list {
            guard (raw[kCGWindowOwnerPID] as? NSNumber)?.int32Value == processIdentifier else { continue }
            guard (raw[kCGWindowLayer] as? NSNumber)?.intValue == 0 else { continue }
            guard let title = raw[kCGWindowName] as? String,
                  title.trimmingCharacters(in: .whitespacesAndNewlines) == normalized else { continue }
            guard let bounds = raw[kCGWindowBounds] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds),
                  rect.width >= 80, rect.height >= 60 else { continue }
            candidates.append(rect)
        }
        return candidates.max { $0.width * $0.height < $1.width * $1.height }
    }

    private static func windowInfo(forWindowID windowID: CGWindowID) -> [CFString: Any]? {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]] else { return nil }
        return list.first { raw in
            (raw[kCGWindowNumber] as? NSNumber)?.uint32Value == windowID
        }
    }

    // MARK: - AX 查询

    /// 读取 AX 元素所属的窗口元素。
    ///
    /// AX 元素的 `kAXWindowAttribute` 指向所属窗口（已实测对按钮、静态文本等
    /// 多种角色都可用）。窗口元素本身用于注册移动/缩放观察。
    static func axWindowElement(of element: AXUIElement) -> AXUIElement? {
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &windowValue) == .success,
              let windowValue else { return nil }
        return unsafeDowncast(windowValue, to: AXUIElement.self)
    }

    /// 读取 AX 元素所属窗口的 Quartz 矩形。
    ///
    /// AX 元素的 `kAXWindowAttribute` 指向所属窗口（已实测对按钮、静态文本等
    /// 多种角色都可用），再从窗口读位置与尺寸。
    static func axWindowRect(of element: AXUIElement) -> CGRect? {
        guard let windowElement = axWindowElement(of: element) else { return nil }
        guard let position = axPoint(of: windowElement, attribute: kAXPositionAttribute),
              let size = axSize(of: windowElement, attribute: kAXSizeAttribute) else { return nil }
        return CGRect(origin: position, size: size)
    }

    /// 读取 AX 元素的点属性。
    static func axPoint(of element: AXUIElement, attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        AXValueGetValue(raw as! AXValue, .cgPoint, &point)
        return point
    }

    /// 读取 AX 元素的尺寸属性。
    static func axSize(of element: AXUIElement, attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let raw = value,
              CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        AXValueGetValue(raw as! AXValue, .cgSize, &size)
        return size
    }
}

/// 监听目标窗口的移动与缩放，让遮罩始终贴合窗口边界。
///
/// - Note: 遮罩跟不上的后果是「遮罩还挂在旧位置」，用户会看到一个悬空的
///   提示块。因此观察失败时必须退化为「不再跟随」而不是「持续错位」。
@MainActor
final class ComputerUseWindowGeometryObserver {
    /// `AXObserver` 是 CF 类型，不满足 Sendable。
    ///
    /// 标记为 `nonisolated(unsafe)` 是安全的：它只在主线程上被创建与销毁，
    /// 且 `deinit` 中的 runloop source 移除不触碰其他隔离域。
    private nonisolated(unsafe) var observer: AXObserver?
    private var observedWindow: AXUIElement?

    init() {}

    deinit {
        // `AXObserver` 的 runloop source 由 CFRunLoop 持有，停止时必须显式移除。
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    /// 开始观察指定窗口。
    ///
    /// - Parameters:
    ///   - processIdentifier: 窗口所属进程。
    ///   - windowElement: 目标 AX 窗口元素。
    func start(processIdentifier: pid_t, windowElement: AXUIElement) {
        stop()
        var created: AXObserver?
        let result = AXObserverCreate(processIdentifier, { _, _, _, _ in
            // 回调来自系统线程；几何读取统一在主线程按需触发。
        }, &created)
        guard result == .success, let created else { return }
        let moved = AXObserverAddNotification(created, windowElement, kAXWindowMovedNotification as CFString, nil)
        let resized = AXObserverAddNotification(created, windowElement, kAXWindowResizedNotification as CFString, nil)
        guard moved == .success || resized == .success else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        observedWindow = windowElement
    }

    /// 停止观察并释放 runloop source。
    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        observedWindow = nil
    }

    /// 主动读取一次当前几何。
    ///
    /// 观察通知可能丢失（应用重建窗口、AX 状态变化），因此调用方应在
    /// 关键时机主动刷新一次。
    func currentRect() -> CGRect? {
        guard let observedWindow else { return nil }
        guard let position = ComputerUseTargetGeometryProvider.axPoint(of: observedWindow, attribute: kAXPositionAttribute),
              let size = ComputerUseTargetGeometryProvider.axSize(of: observedWindow, attribute: kAXSizeAttribute) else { return nil }
        return CGRect(origin: position, size: size)
    }
}
