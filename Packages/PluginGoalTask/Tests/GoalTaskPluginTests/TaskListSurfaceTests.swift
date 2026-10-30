import Testing
import Foundation
import SwiftUI
import AppKit
@testable import GoalTaskPlugin

/// 任务列表容器内阴影的渲染验证。
///
/// 背景:容器原先复用 LumiUI 的 `appInputSurface`,该实现把「挖空块」整体向下偏移,
/// 顶边留下完整阴影带、底边被挖空块完全覆盖、阴影几乎为零,封闭容器看起来像被一刀切断。
/// 换成本插件的 `taskListSurface`(上下各内缩同样的距离)后,上下应当对称。
///
/// 这里直接渲染并逐像素量上下边缘的暗度,把主观的「看起来强/弱」变成可断言的数字,
/// 避免以后有人改回不对称实现时没有任何信号。
@MainActor
@Suite("Task List Surface Tests")
struct TaskListSurfaceTests {

    /// 渲染视图,返回指定列自上而下的 R 通道灰度。
    ///
    /// 走 `NSBitmapImageRep` 而不是 `CGContext.draw`:后者在自建上下文里会把图像上下翻转,
    /// 量出来的上下会整个反过来,结论完全相反。
    private func renderColumn(
        of view: some View,
        width: Int,
        height: Int,
        x: Int
    ) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.isOpaque = false

        let cgImage = try #require(renderer.cgImage, "ImageRenderer 未产出图像")
        let rep = NSBitmapImageRep(cgImage: cgImage)
        #expect(rep.pixelsWide == width && rep.pixelsHigh == height, "渲染尺寸与预期不符")

        return (0..<height).map { y in
            let red = rep.colorAt(x: x, y: y)?.redComponent ?? 1
            return UInt8(max(0, min(255, (red * 255).rounded())))
        }
    }

    /// 构造一个内容刚好装满、不发生滚动的任务列表容器。
    ///
    /// 3 行任务的内容高度 = 3 × 30(行高) + 2 × 4(行距) + 8(上下内边距) = 106pt,
    /// 小于 `SidebarView.maxTaskListHeight`,因此容器的底边是真实边界而不是裁切线,
    /// 底部的 4px 内边距也完整可见,阴影带才量得到。
    private func makeFilledContainer() -> (view: some View, height: Int) {
        let tasks = (1...3).map { index in
            GoalTask(
                goalId: "g",
                title: "任务 \(index)",
                status: .pending,
                order: index
            )
        }
        let items = tasks.map { GoalTaskDisplayItem(from: $0) }
        let contentHeight = 3 * 30 + 2 * 4 + 8

        let view = ZStack {
            Color.white
            SidebarTaskList(tasks: items)
        }
        .frame(width: 200, height: CGFloat(contentHeight))

        return (view, contentHeight)
    }

    /// 容器底边必须有和顶边一样强的阴影带。
    ///
    /// 改造前底边只剩模糊残留(最暗约 241),几乎看不出来,这条断言是本次改动的核心。
    @Test("容器底边存在可见阴影带")
    func bottomEdgeHasVisibleShadow() throws {
        let container = makeFilledContainer()
        let column = try renderColumn(
            of: container.view,
            width: 200,
            height: container.height,
            x: 100
        )

        // 白色底色是 255,阴影会让它明显变暗。
        let darkestBottom = column.suffix(6).min() ?? 255

        #expect(darkestBottom < 220, "底边最暗值 \(darkestBottom) 仍接近白色,说明底边没有阴影")
    }

    /// 顶边与底边的阴影强度应当一致。
    @Test("顶边与底边阴影强度对称")
    func topAndBottomShadowAreSymmetric() throws {
        let container = makeFilledContainer()
        let column = try renderColumn(
            of: container.view,
            width: 200,
            height: container.height,
            x: 100
        )

        let darkestTop = column.prefix(6).min() ?? 255
        let darkestBottom = column.suffix(6).min() ?? 255

        // 改造前顶边约 146、底边约 241,差值 95;对称后差值应收敛到个位数。
        #expect(
            abs(Int(darkestTop) - Int(darkestBottom)) <= 6,
            "顶边最暗 \(darkestTop) 与底边最暗 \(darkestBottom) 差异过大,上下不对称"
        )
    }

    /// 底边的阴影带应当是顶边的镜像,而不只是「差不多有个影子」。
    @Test("底边阴影带与顶边逐行镜像")
    func bottomBandMirrorsTopBand() throws {
        let container = makeFilledContainer()
        let column = try renderColumn(
            of: container.view,
            width: 200,
            height: container.height,
            x: 100
        )

        let band = 6
        for offset in 0..<band {
            let top = Int(column[column.startIndex + offset])
            let bottom = Int(column[column.index(column.endIndex, offsetBy: -1 - offset)])
            #expect(
                abs(top - bottom) <= 8,
                "距边 \(offset) px 处:顶边 \(top) 与底边 \(bottom) 不是镜像关系"
            )
        }
    }

    /// 顶边不能被这次改动「改弱」——它必须和改造前一样强。
    @Test("顶边阴影强度保持不变")
    func topEdgeShadowStaysStrong() throws {
        let container = makeFilledContainer()
        let column = try renderColumn(
            of: container.view,
            width: 200,
            height: container.height,
            x: 100
        )

        let darkestTop = column.prefix(6).min() ?? 255

        // 改造前实测顶边最暗约 210~214,这里留出余量但不允许塌到接近白色。
        #expect(darkestTop < 235, "顶边最暗值 \(darkestTop) 偏弱,顶边阴影被削弱了")
    }
}
