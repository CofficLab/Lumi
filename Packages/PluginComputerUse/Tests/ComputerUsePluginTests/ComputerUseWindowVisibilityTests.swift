import CoreGraphics
import Foundation
import Testing
@testable import ComputerUsePlugin

/// 目标窗口**可见区域**计算的行为约定。
///
/// 这组测试守护的是用户最直接的困惑来源：
/// 「Lumi 明明在操作窗口 A，遮罩为什么压在窗口 B 上面？」
///
/// 答案只有一个：遮罩铺的是 A 的**完整**矩形，而 A 被 B 挡住了。
/// 修复方式是把遮罩裁剪到 A 真正露出来的部分，于是这里必须保证：
///
/// 1. 被遮挡的部分确实从可见区域里**扣除**了；
/// 2. 扣除后剩下的区域**并集**仍等于原矩形减去交集（不能丢像素）；
/// 3. 完全被遮挡时可见区域为空（此时不该画遮罩）；
/// 4. 残留的细条区域被丢弃（画出来只有噪点）。
@Suite("Computer Use 目标窗口可见区域")
struct ComputerUseWindowVisibilityTests {
    // MARK: - 无遮挡

    @Test("没有遮挡时可见区域就是目标矩形本身")
    func noOccluderKeepsWholeTarget() {
        let target = CGRect(x: 100, y: 100, width: 400, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [])

        #expect(regions.count == 1)
        #expect(regions.first == target)
    }

    // MARK: - 部分遮挡

    @Test("遮挡物从右侧压入时，可见区域只剩左侧一条")
    func rightOccluderLeavesLeftBand() {
        // 目标 0,0,400x300；遮挡物压住右半边 200,0,200,300。
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluder = CGRect(x: 200, y: 0, width: 200, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [occluder])

        #expect(regions.count == 1)
        let region = regions[0]
        #expect(region.minX == 0)
        #expect(region.width == 200)
        #expect(region.height == 300)
    }

    @Test("遮挡物从上方压入时，可见区域只剩下方一条")
    func topOccluderLeavesBottomBand() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluder = CGRect(x: 0, y: 0, width: 400, height: 100)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [occluder])

        #expect(regions.count == 1)
        let region = regions[0]
        #expect(region.minY == 100)
        #expect(region.height == 200)
    }

    @Test("遮挡物压在中间时，可见区域被切成上下两条")
    func middleOccluderSplitsTarget() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluder = CGRect(x: 0, y: 100, width: 400, height: 100)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [occluder])

        #expect(regions.count == 2)
        let totalArea = regions.reduce(0) { $0 + $1.width * $1.height }
        #expect(abs(totalArea - 400 * 200) < 0.5)
    }

    @Test("遮挡物只压住一角时，可见区域仍覆盖绝大部分目标")
    func cornerOccluderKeepsMostOfTarget() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluder = CGRect(x: 300, y: 0, width: 100, height: 100)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [occluder])

        let covered = regions.reduce(0) { $0 + $1.width * $1.height }
        // 被挖掉的面积是 100x100 = 10000，剩余 400*300 - 10000 = 110000。
        #expect(abs(covered - 110_000) < 0.5)
    }

    // MARK: - 完全遮挡

    @Test("完全被遮挡时可见区域为空")
    func fullyOccludedTargetHasNoVisibleRegion() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluder = CGRect(x: -50, y: -50, width: 500, height: 400)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [occluder])

        #expect(regions.isEmpty)
    }

    // MARK: - 区域完整性

    @Test("多个遮挡物叠加后，可见区域总面积等于原面积减去被遮面积")
    func multipleOccludersPreserveArea() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluders = [
            CGRect(x: 0, y: 0, width: 400, height: 100),
            CGRect(x: 0, y: 200, width: 400, height: 100)
        ]
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: occluders)

        let covered = regions.reduce(0) { $0 + $1.width * $1.height }
        // 上下各遮掉 100，中间剩下 400x100 = 40000。
        #expect(abs(covered - 40_000) < 0.5)
    }

    @Test("可见区域互不重叠")
    func visibleRegionsDoNotOverlap() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluders = [
            CGRect(x: 0, y: 0, width: 400, height: 100),
            CGRect(x: 0, y: 200, width: 400, height: 100)
        ]
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: occluders)

        for (index, first) in regions.enumerated() {
            for second in regions.dropFirst(index + 1) {
                #expect(first.intersection(second).isNull)
            }
        }
    }

    @Test("残留的细条区域被丢弃")
    func sliverRegionsAreDiscarded() {
        // 遮挡物几乎盖满目标，只在右侧留下 10px 宽的条——小于最小可见尺寸。
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let occluder = CGRect(x: 0, y: 0, width: 390, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [occluder])

        #expect(regions.isEmpty)
    }

    // MARK: - 退化输入

    @Test("退化尺寸的目标矩形没有可见区域")
    func degenerateTargetHasNoVisibleRegion() {
        #expect(ComputerUseWindowVisibility.visibleRegions(target: .zero, occluders: []).isEmpty)
    }

    @Test("与目标不相交的遮挡物不产生影响")
    func nonIntersectingOccluderIsIgnored() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let faraway = CGRect(x: 5_000, y: 5_000, width: 200, height: 200)
        let regions = ComputerUseWindowVisibility.visibleRegions(target: target, occluders: [faraway])

        #expect(regions.count == 1)
        #expect(regions.first == target)
    }

    // MARK: - 目标定位

    @Test("按窗口 ID 定位目标时，排在目标前面的窗口都算遮挡者")
    func windowsInFrontOfTargetAreOccluders() {
        // 构造窗口列表：索引 0 最前（遮挡者），索引 1 是目标，索引 2 在后面。
        let windows: [[CFString: Any]] = [
            Self.window(number: 100, pid: 999, rect: CGRect(x: 0, y: 0, width: 400, height: 300)),
            Self.window(number: 200, pid: 111, rect: CGRect(x: 0, y: 0, width: 400, height: 300)),
            Self.window(number: 300, pid: 111, rect: CGRect(x: 0, y: 0, width: 400, height: 300))
        ]
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(
            target: target,
            targetWindowID: 200,
            processIdentifier: 111,
            windows: windows
        )

        // 索引 0 的窗口完全盖住目标 → 目标完全不可见 → 不应绘制遮罩。
        #expect(regions?.isEmpty == true)
    }

    @Test("排在目标后面的窗口不算遮挡者")
    func windowsBehindTargetAreNotOccluders() {
        let windows: [[CFString: Any]] = [
            Self.window(number: 200, pid: 111, rect: CGRect(x: 0, y: 0, width: 400, height: 300)),
            Self.window(number: 300, pid: 999, rect: CGRect(x: 0, y: 0, width: 400, height: 300))
        ]
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(
            target: target,
            targetWindowID: 200,
            processIdentifier: 111,
            windows: windows
        )

        // 后面的窗口盖不住目标 → 目标完全可见。
        #expect(regions?.count == 1)
        #expect(regions?.first == target)
    }

    @Test("没有窗口 ID 时按进程与矩形重叠近似匹配目标")
    func targetIsMatchedByProcessAndOverlap() {
        let windows: [[CFString: Any]] = [
            Self.window(number: 300, pid: 999, rect: CGRect(x: 0, y: 0, width: 400, height: 300)),
            Self.window(number: 400, pid: 111, rect: CGRect(x: 0, y: 0, width: 400, height: 300))
        ]
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(
            target: target,
            targetWindowID: nil,
            processIdentifier: 111,
            windows: windows
        )

        // 索引 0 的窗口盖住目标 → 目标不可见。
        #expect(regions?.isEmpty == true)
    }

    @Test("浮动层窗口同样是遮挡者")
    func floatingWindowIsOccluder() {
        // 浮动工具面板 layer = 3，完全盖住普通目标窗口。
        // 只看 layer == 0 会把它当成不存在，露出整块被挡住的区域。
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let windows: [[CFString: Any]] = [
            Self.window(number: 100, pid: 999, rect: target, layer: 3),
            Self.window(number: 200, pid: 111, rect: target)
        ]
        let regions = ComputerUseWindowVisibility.visibleRegions(
            target: target,
            targetWindowID: 200,
            processIdentifier: 111,
            windows: windows
        )

        #expect(regions?.isEmpty == true)
    }

    @Test("自身遮罩面板不计入遮挡者")
    func overlayPanelIsExcluded() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let windows: [[CFString: Any]] = [
            // Lumi 自己的遮罩面板：高层级且与目标完全重合。
            Self.window(number: 900, pid: 222, rect: target, layer: 1_000),
            Self.window(number: 200, pid: 111, rect: target)
        ]
        let targetArguments = (
            target: target,
            targetWindowID: CGWindowID(200),
            processIdentifier: pid_t(111)
        )

        // 不排除时遮罩会被自己的面板扣成空。
        let unexcluded = ComputerUseWindowVisibility.visibleRegions(
            target: targetArguments.target,
            targetWindowID: targetArguments.targetWindowID,
            processIdentifier: targetArguments.processIdentifier,
            windows: windows
        )
        #expect(unexcluded?.isEmpty == true)

        let excluded = ComputerUseWindowVisibility.visibleRegions(
            target: targetArguments.target,
            targetWindowID: targetArguments.targetWindowID,
            processIdentifier: targetArguments.processIdentifier,
            windows: windows,
            excludingWindowID: 900
        )
        #expect(excluded == [target])
    }

    @Test("窗口列表为空时无法定位目标")
    func emptyWindowListCannotLocateTarget() {
        let target = CGRect(x: 0, y: 0, width: 400, height: 300)
        let regions = ComputerUseWindowVisibility.visibleRegions(
            target: target,
            targetWindowID: 200,
            processIdentifier: 111,
            windows: []
        )

        #expect(regions == nil)
    }

    // MARK: - 辅助

    /// 构造一条 `CGWindowListCopyWindowInfo` 风格的窗口记录。
    private static func window(
        number: UInt32,
        pid: Int32,
        rect: CGRect,
        layer: Int = 0
    ) -> [CFString: Any] {
        [
            kCGWindowNumber as CFString: number,
            kCGWindowOwnerPID as CFString: pid,
            kCGWindowLayer as CFString: layer,
            kCGWindowAlpha as CFString: 1.0,
            kCGWindowBounds as CFString: [
                "X" as CFString: Int(rect.minX),
                "Y" as CFString: Int(rect.minY),
                "Width" as CFString: Int(rect.width),
                "Height" as CFString: Int(rect.height)
            ]
        ]
    }
}
