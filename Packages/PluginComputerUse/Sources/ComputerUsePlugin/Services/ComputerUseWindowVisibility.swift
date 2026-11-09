import CoreGraphics
import Foundation

/// 目标窗口在桌面上的**可见区域**。
///
/// ## 为什么需要它
///
/// 遮罩面板的层级是 `.screenSaver`，永远盖在所有窗口之上；而遮罩的矩形
/// 又是目标窗口 A 的**完整**矩形。当 A 被另一个窗口 B 挡住时，遮罩会连同
/// 「Lumi 正在操作 A」的角标一起压在 B 上面——用户看到角标落在 B 身上，
/// 会以为 Lumi 正在操作 B，认知完全错位。
///
/// ## 解法
///
/// 遮罩只覆盖 A **真正可见**的部分：
/// 1. `CGWindowListCopyWindowInfo(.optionOnScreenOnly, ...)` 返回当前 Space
///    的窗口，顺序是**自前向后**；
/// 2. 排在目标窗口前面的那些窗口就是遮挡者；
/// 3. 用遮挡者从目标矩形里「挖洞」，剩下的部分即可见区域。
///
/// - Note: 完全被遮挡时可见区域为空，此时**不应绘制遮罩**——用户根本看不到
///   A 的变化，自然也不需要提示。硬画只会把角标按在遮挡者身上。
enum ComputerUseWindowVisibility {
    /// 绘制遮罩所需的最小可见区域尺寸。
    ///
    /// 细如发丝的残留区域画出来只有噪点，直接丢弃。
    static let minimumVisibleSize = CGSize(width: 24, height: 24)

    // MARK: - 可见区域计算

    /// 从目标矩形里扣除遮挡窗口，得到若干互不重叠的可见矩形。
    ///
    /// - Parameters:
    ///   - target: 目标窗口矩形（Quartz 桌面坐标）。
    ///   - occluders: 位于目标窗口**之上**的窗口矩形（Quartz 桌面坐标）。
    /// - Returns: 可见矩形，按面积从大到小排列。完全被遮挡时返回空数组。
    static func visibleRegions(target: CGRect, occluders: [CGRect]) -> [CGRect] {
        guard target.width > 0, target.height > 0 else { return [] }
        var regions = [target]
        for occluder in occluders {
            guard occluder.width > 0, occluder.height > 0 else { continue }
            regions = regions.flatMap { subtract($0, occluder) }
        }
        return regions
            .filter { $0.width >= minimumVisibleSize.width && $0.height >= minimumVisibleSize.height }
            .sorted { $0.width * $0.height > $1.width * $1.height }
    }

    /// 用一个矩形从另一个矩形里挖掉一块，得到互不重叠的剩余矩形。
    ///
    /// 采用「四段式」切分（上 / 下 / 左 / 右）：切分结果彼此不重叠，
    /// 且并集恰好等于原矩形减去交集，逐个遮挡者迭代即可得到全部可见区域。
    private static func subtract(_ rect: CGRect, _ hole: CGRect) -> [CGRect] {
        let intersection = rect.intersection(hole)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else {
            return [rect]
        }
        var result: [CGRect] = []
        // 上
        if intersection.minY > rect.minY {
            result.append(CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: intersection.minY - rect.minY
            ))
        }
        // 下
        if intersection.maxY < rect.maxY {
            result.append(CGRect(
                x: rect.minX,
                y: intersection.maxY,
                width: rect.width,
                height: rect.maxY - intersection.maxY
            ))
        }
        // 左
        if intersection.minX > rect.minX {
            result.append(CGRect(
                x: rect.minX,
                y: intersection.minY,
                width: intersection.minX - rect.minX,
                height: intersection.height
            ))
        }
        // 右
        if intersection.maxX < rect.maxX {
            result.append(CGRect(
                x: intersection.maxX,
                y: intersection.minY,
                width: rect.maxX - intersection.maxX,
                height: intersection.height
            ))
        }
        return result
    }

    // MARK: - 遮挡者查询

    /// 计算目标窗口的可见区域。
    ///
    /// - Parameters:
    ///   - target: 目标窗口矩形（Quartz 桌面坐标）。
    ///   - targetWindowID: 目标窗口的 `CGWindowID`；AX 路径拿不到时传 `nil`，
    ///     改用「进程 + 矩形重叠」近似匹配。
    ///   - processIdentifier: 目标窗口所属进程。
    ///   - windows: 窗口列表；为 `nil` 时实时查询当前 Space 的窗口。
    ///   - excludingWindowID: 需要忽略的窗口（Lumi 自己的遮罩面板）。
    ///     遮罩覆盖整个目标，不排除会把可见区域整个扣光。
    /// - Returns:
    ///   - 可见矩形（Quartz 桌面坐标），按面积从大到小排列；
    ///   - `nil` 表示**无法定位目标窗口**——它可能在别的 Space、已最小化，
    ///     或者压根不在屏幕上。此时不能假设它「完全可见」，否则会把遮罩
    ///     画到遮挡者身上，正是要修的那个问题。
    static func visibleRegions(
        target: CGRect,
        targetWindowID: CGWindowID?,
        processIdentifier: pid_t?,
        windows: [[CFString: Any]]? = nil,
        excludingWindowID: CGWindowID? = nil
    ) -> [CGRect]? {
        let list = windows ?? onScreenWindows()
        guard !list.isEmpty else { return nil }
        guard let index = indexOfTarget(
            in: list,
            targetWindowID: targetWindowID,
            processIdentifier: processIdentifier,
            targetRect: target
        ) else { return nil }
        // 列表自前向后排列：排在目标前面的窗口都压在目标之上。
        //
        // 不能只认 `layer == 0`：浮动面板、工具面板、菜单等非零层级的窗口
        // 同样会真实挡住目标；唯一要精确排除的是 Lumi 自己的遮罩面板。
        let occluders = list[..<index].compactMap { window -> CGRect? in
            if let excludingWindowID,
               (window[kCGWindowNumber] as? NSNumber)?.uint32Value == excludingWindowID {
                return nil
            }
            guard (window[kCGWindowAlpha] as? NSNumber)?.doubleValue ?? 1 > 0.01 else { return nil }
            guard let rect = rect(of: window), rect.intersects(target) else { return nil }
            return rect
        }
        return visibleRegions(target: target, occluders: occluders)
    }

    /// 定位目标窗口在列表中的下标。
    ///
    /// AX 路径只有 AX 元素、拿不到 `CGWindowID`，只能按「进程 + 矩形重叠」
    /// 近似匹配：同一进程里与目标矩形重叠最多的那个窗口即为目标窗口。
    private static func indexOfTarget(
        in list: [[CFString: Any]],
        targetWindowID: CGWindowID?,
        processIdentifier: pid_t?,
        targetRect: CGRect
    ) -> Int? {
        if let targetWindowID,
           let index = list.firstIndex(where: {
               ($0[kCGWindowNumber] as? NSNumber)?.uint32Value == targetWindowID
           }) {
            return index
        }
        guard let processIdentifier else { return nil }
        var bestIndex: Int?
        var bestOverlap: CGFloat = 0
        for (index, window) in list.enumerated() {
            guard (window[kCGWindowOwnerPID] as? NSNumber)?.int32Value == processIdentifier else { continue }
            guard (window[kCGWindowLayer] as? NSNumber)?.intValue == 0 else { continue }
            guard let rect = rect(of: window) else { continue }
            let intersection = rect.intersection(targetRect)
            guard !intersection.isNull else { continue }
            let overlap = intersection.width * intersection.height
            guard overlap > bestOverlap else { continue }
            bestOverlap = overlap
            bestIndex = index
        }
        guard let bestIndex else { return nil }
        // 重叠太小说明匹配到的是同进程的别的窗口，不能据此判断遮挡关系。
        let targetArea = targetRect.width * targetRect.height
        guard targetArea > 0, bestOverlap >= targetArea * 0.6 else { return nil }
        return bestIndex
    }

    /// 当前 Space 中可见的窗口列表（自前向后）。
    static func onScreenWindows() -> [[CFString: Any]] {
        (CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[CFString: Any]]) ?? []
    }

    /// 读取窗口矩形。
    private static func rect(of window: [CFString: Any]) -> CGRect? {
        guard let bounds = window[kCGWindowBounds] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }
}
