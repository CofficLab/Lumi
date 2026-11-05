import Testing
import Foundation
import SwiftUI
import AppKit
@testable import GoalTaskPlugin

/// Goal 面板顶部阴影的渲染级测试。
///
/// ## 为什么单独测
///
/// 顶部阴影是**溢出**面板顶边、画在上方区域里的一层阴影:面板本身没有底色
/// (与聊天区同底),SwiftUI 的 `.shadow()` 画不出这种「整条面板浮起来」的层次,
/// 只能手绘并把它上移到面板之外。
///
/// 这层效果有三个只能靠渲染发现的失效点:
/// - 阴影没画出来(阴影被裁掉 / 面板没有底色导致 `.shadow()` 失效);
/// - 渐变方向反了(阴影落到面板内部,变成一条脏兮兮的内阴影);
/// - 没有活跃 goal 时阴影没跟着收起(面板高度为 0,却在上方留一条黑边)。
///
/// ## 为什么断言「顶端可辨衰减」而不是「顶端纯白」
///
/// 阴影改成与面板下方任务列表容器同源的「模糊挖空」写法后,顶端不再是一条
/// 硬边,而是由高斯衰减自然渐隐。旧实现是线性渐变,顶端直接落到全透明,
/// 因此旧测试断言 `> 250`(纯白)。
///
/// 新的契约是:**从上沿到面板顶边,亮度必须单调递减**——这正是「阴影在衰减」
/// 的可测量表述。若有人改回硬边渐变(上沿处出现可见的亮度突变),
/// 这条断言会立刻失败。
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

        // 阴影带最上沿:高斯衰减后已很淡,但不能是纯白——那说明阴影根本没铺到这。
        let shadowTop = rowBrightness(rep, y: header - Int(GoalTopShadowView.bandHeight))
        #expect(shadowTop < 255, "阴影带上沿亮度 \(shadowTop) 是纯白,阴影没有覆盖到这一行")

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

    /// 阴影带必须**单调衰减**:越往上越淡。
    ///
    /// 这是「模糊挖空」写法的核心契约。旧实现是线性渐变,顶端直接落到全透明,
    /// 于是上沿处存在可见的亮度突变;改成高斯衰减后,整条带上不存在突变。
    ///
    /// 若有人把实现改回硬边渐变或加上一段突兀的遮罩,这条断言会失败。
    @Test("顶部阴影沿高度单调衰减,顶端无亮度突变")
    func topShadowFadesMonotonically() throws {
        let header = 40
        let composite = VStack(spacing: 0) {
            Color.white.frame(height: CGFloat(header))
            SidebarView(viewModel: makeViewModel(), forkCoordinator: nil)
        }
        .frame(width: 300)

        let rep = try render(composite, width: 300, height: header + 44)

        let bandHeight = Int(GoalTopShadowView.bandHeight)
        var profile: [Double] = []
        for y in (header - bandHeight)..<header {
            profile.append(rowBrightness(rep, y: y))
        }

        // 上沿必须可见(否则说明阴影整体没画出来)。
        #expect(profile[0] < 255, "阴影带上沿是纯白,阴影没有铺到这一行")

        // 逐行朝面板顶边走,亮度必须单调不增(越靠近顶边阴影越重 = 越暗)。
        // 容差 1.5 是为了吸收抗锯齿带来的 ±1 抖动。
        for index in 1..<profile.count {
            #expect(
                profile[index] <= profile[index - 1] + 1.5,
                "第 \(index) 行亮度 \(profile[index]) 比上一行 \(profile[index - 1]) 更亮,阴影衰减不单调"
            )
        }
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
