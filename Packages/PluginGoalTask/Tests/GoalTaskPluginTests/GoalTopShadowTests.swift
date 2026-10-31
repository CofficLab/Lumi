import Testing
import Foundation
import SwiftUI
import AppKit
@testable import GoalTaskPlugin

/// Goal 面板顶部阴影的渲染级测试。
///
/// ## 为什么单独测
///
/// 顶部阴影是**溢出**面板顶边、画在上方区域里的一层渐变:面板本身没有底色
/// (与聊天区同底),SwiftUI 的 `.shadow()` 画不出这种「整条面板浮起来」的层次,
/// 只能手绘渐变并把它上移到面板之外。
///
/// 这层效果有三个只能靠渲染发现的失效点:
/// - 渐变没画出来(阴影被裁掉 / 面板没有底色导致 `.shadow()` 失效);
/// - 渐变方向反了(阴影落到面板内部,变成一条脏兮兮的内阴影);
/// - 没有活跃 goal 时阴影没跟着收起(面板高度为 0,却在上方留一条黑边)。
@MainActor
@Suite("Goal Top Shadow Tests")
struct GoalTopShadowTests {

    // MARK: - 渲染辅助

    /// 渲染视图并返回位图(1x,1 像素 = 1 点)。
    private func render(_ view: some View, width: Int, height: Int) throws -> NSBitmapImageRep {
        let renderer = ImageRenderer(
            content: ZStack {
                Color.white
                view
            }
        )
        renderer.scale = 1
        renderer.isOpaque = false

        let cgImage = try #require(renderer.cgImage, "ImageRenderer 未产出图像")
        let rep = NSBitmapImageRep(cgImage: cgImage)
        #expect(rep.pixelsWide == width && rep.pixelsHigh == height, "渲染尺寸与预期不符")
        return rep
    }

    /// 某一行的平均灰度。
    ///
    /// 取行平均而不是取单个像素:阴影是整行铺开的,单个像素可能被面板里的
    /// 文字或图标污染(比如标题、按钮正好落在那一行)。
    private func rowBrightness(_ rep: NSBitmapImageRep, y: Int) -> Double {
        var total = 0.0
        var count = 0
        for x in 0..<rep.pixelsWide {
            guard let color = rep.colorAt(x: x, y: y) else { continue }
            total += color.redComponent * 255
            count += 1
        }
        guard count > 0 else { return 255 }
        return total / Double(count)
    }

    /// 构造一个带活跃 goal 的视图模型。
    ///
    /// 不挂任务,面板高度就只有标题栏那 44pt,顶边位置好推算。
    private func makeViewModel() -> GoalVM {
        let vm = GoalVM(managerProvider: { nil })
        let goal = Goal(
            conversationId: "c",
            title: "LumiPluginBookletMaker 全量测试",
            status: .inProgress
        )
        vm.goals = [
            GoalListItem(
                goal: GoalDisplayItem(from: goal),
                tasks: []
            )
        ]
        return vm
    }

    // MARK: - Tests

    /// 阴影确实画在面板顶边**之上**,并且越靠近顶边越重。
    ///
    /// 合成画面:白色留白 24pt + Goal 面板。面板顶边落在 y=24,
    /// 阴影带覆盖 y ∈ [24 - 高度, 24]。
    @Test("顶部阴影落在面板顶边之上并向顶边渐强")
    func topShadowRendersAbovePanelEdge() throws {
        let header = 24
        let composite = VStack(spacing: 0) {
            Color.white.frame(height: CGFloat(header))
            SidebarView(viewModel: makeViewModel(), forkCoordinator: nil)
        }
        .frame(width: 300)

        let rep = try render(composite, width: 300, height: header + 44)

        // 阴影带最上沿:此时渐变已衰减为透明,应当还是白底。
        let shadowTop = rowBrightness(rep, y: header - Int(SidebarView.topShadowHeight))
        #expect(shadowTop > 250, "阴影带上沿亮度 \(shadowTop) 过低,阴影范围超出了预期")

        // 紧贴面板顶边的一行:阴影最重,必须明显比上沿暗。
        let shadowEdge = rowBrightness(rep, y: header - 1)
        #expect(
            shadowEdge < shadowTop - 15,
            "顶边处亮度 \(shadowEdge) 与上沿 \(shadowTop) 差异过小,顶部阴影没画出来"
        )

        // 阴影不得渗进面板内部(否则会变成一条压在上沿的内阴影)。
        let inside = rowBrightness(rep, y: header + 2)
        #expect(inside > 250, "面板内部亮度 \(inside) 过低,阴影渗进了面板内")
    }

    /// 没有活跃 goal 时不画阴影。
    ///
    /// 面板高度为 0,但阴影是溢出到面板之外的渐变——一旦忘记用 `hasVisibleGoal`
    /// 收口,聊天区上方就会凭空多出一条黑边。
    @Test("没有活跃 goal 时不画顶部阴影")
    func noShadowWithoutActiveGoal() throws {
        let header = 24
        let emptyVM = GoalVM(managerProvider: { nil })
        let composite = VStack(spacing: 0) {
            Color.white.frame(height: CGFloat(header))
            SidebarView(viewModel: emptyVM, forkCoordinator: nil)
        }
        .frame(width: 300)

        let rep = try render(composite, width: 300, height: header)

        for y in 0..<header {
            #expect(
                rowBrightness(rep, y: y) > 250,
                "y=\(y) 处亮度 \(rowBrightness(rep, y: y)) 过低,没有 goal 时不该有阴影"
            )
        }
    }
}
