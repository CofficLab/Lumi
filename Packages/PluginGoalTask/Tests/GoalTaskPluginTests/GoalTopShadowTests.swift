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
/// ## 断言的是「投影形状」而不是「某个具体像素值」
///
/// 一道真实的投影有两个可测量的特征:
///
/// 1. **贴着面板顶边有一条实心接触线**——面板边缘挡住光,阴影在该处最浓;
/// 2. **向上单调衰减**——越过接触线后按高斯衰减,越往上越淡。
///
/// 早期实现是「模糊挖空」:用 `destinationOut` 挖掉顶端,靠 `.blur()` 把挖空
/// 边界变软。问题在于 `.blur()` 作用在**挖空块自己**身上,模糊向下的一半
/// 正好侵入核心区,把本该实心的接触线削掉——实测核心区保留率只有 0.55~0.81,
/// 于是剖面变成「中间鼓、两头平」,阴影读起来是浮在面板上方的一条灰带,
/// 而不是面板压出来的接触阴影。
///
/// 现在形状由高斯函数直接决定,这些断言就是在钉住那个形状。
///
/// ## 坐标约定
///
/// `NSBitmapImageRep.colorAt(x:y:)` 的 y **自顶向下**(y=0 是图像最上一行)。
/// 下面的 `panelTopRow` 就是面板顶边所在的行号。
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
    /// - Parameter y: **自顶向下**的行索引(y=0 是图像最上一行)。
    ///   `NSBitmapImageRep.colorAt(x:y:)` 用的是这个方向,别与 CoreGraphics
    ///   的自底向上坐标混淆。
    /// - Note: 取行平均而不是取单个像素:阴影是整行铺开的,单个像素可能被面板里的
    ///   文字或图标污染(比如标题、按钮正好落在那一行)。
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

    // MARK: - 公共夹具

    /// 面板渲染总高:标题栏 + 底部留白。
    ///
    /// 面板底部与 chat section 底边之间留了一段空白(见
    /// `SidebarView.chatSectionBottomInset`),渲染尺寸必须把它算进去,
    /// 否则 `ImageRenderer` 产出的位图与断言的尺寸对不上。
    private var panelHeight: Int {
        44 + Int(SidebarView.chatSectionBottomInset)
    }

    /// 渲染「白色留白 + Goal 面板」,返回位图与面板顶边所在的行号。
    ///
    /// - Parameter header: 面板上方留白的行数。
    private func renderPanel(header: Int) throws -> (rep: NSBitmapImageRep, panelTopRow: Int) {
        let composite = VStack(spacing: 0) {
            Color.white.frame(height: CGFloat(header))
            SidebarView(viewModel: makeViewModel(), forkCoordinator: nil)
        }
        .frame(width: 300)

        let rep = try render(composite, width: 300, height: header + panelHeight)
        return (rep, header)
    }

    // MARK: - Tests

    /// 阴影确实画在面板顶边**之上**,并且越靠近顶边越重。
    ///
    /// 合成画面:白色留白 + Goal 面板。面板顶边落在 `header` 行,
    /// 阴影带覆盖它上方的若干行。
    @Test("顶部阴影落在面板顶边之上并向顶边渐强")
    func topShadowRendersAbovePanelEdge() throws {
        let header = 24
        let (rep, panelTopRow) = try renderPanel(header: header)

        // 阴影带最上沿:高斯尾部本就趋近于 0,允许接近纯白。
        //
        // 但不能断言「完全没画」——如果整条带都没渲染,这里也是纯白。
        // 区分办法:再往下取一行,那里必须有可见阴影。
        let bandTopRow = panelTopRow - Int(GoalTopShadowView.bandHeight)
        let shadowTop = rowBrightness(rep, y: bandTopRow)
        #expect(shadowTop <= 255, "阴影带上沿亮度异常:\(shadowTop)")

        // 带内靠下的一行(接触线之上)必须有可见阴影,证明整条带确实画出来了。
        let midBand = rowBrightness(rep, y: panelTopRow - 3)
        #expect(midBand < 255, "阴影带中部亮度 \(midBand) 是纯白,阴影没有铺开")

        // 紧贴面板顶边的一行:阴影最重,必须明显比上沿暗。
        let shadowEdge = rowBrightness(rep, y: panelTopRow - 1)
        #expect(
            shadowEdge < shadowTop - 15,
            "顶边处亮度 \(shadowEdge) 与上沿 \(shadowTop) 差异过小,顶部阴影没画出来"
        )

        // 阴影不得渗进面板内部(否则会变成一条压在上沿的内阴影)。
        let inside = rowBrightness(rep, y: panelTopRow + 2)
        #expect(inside > 250, "面板内部亮度 \(inside) 过低,阴影渗进了面板内")
    }

    /// 阴影带必须**单调衰减**:越往上越淡。
    ///
    /// 这是「投影」的形状契约。旧实现是「模糊挖空」,模糊侵入核心区后剖面
    /// 变成中间鼓两头平,单看单调性也能通过——所以这条断言单独不够,
    /// 下面还有两条断言接触线的形状。
    @Test("顶部阴影沿高度单调衰减,顶端无亮度突变")
    func topShadowFadesMonotonically() throws {
        let header = 40
        let (rep, panelTopRow) = try renderPanel(header: header)

        let bandHeight = Int(GoalTopShadowView.bandHeight)
        // 自带顶往下逐行取样:index 0 = 带的上沿,index last = 紧贴面板顶边那一行。
        var profile: [Double] = []
        for offset in stride(from: bandHeight - 1, through: 0, by: -1) {
            profile.append(rowBrightness(rep, y: panelTopRow - 1 - offset))
        }

        // 上沿是高斯尾部,趋近于 0 是正常的;但带内靠下处必须可见。
        #expect(profile[3] < 255, "阴影带内第 4 行是纯白,阴影没有铺开")

        // 逐行朝面板顶边走,亮度必须单调不增(越靠近顶边阴影越重 = 越暗)。
        // 容差 1.5 是为了吸收抗锯齿带来的 ±1 抖动。
        for index in 1..<profile.count {
            #expect(
                profile[index] <= profile[index - 1] + 1.5,
                "自上沿第 \(index) 行处亮度 \(profile[index]) 比上一行 \(profile[index - 1]) 更亮,阴影衰减不单调"
            )
        }
    }

    /// 紧贴面板顶边处必须有一条**实心接触线**,而不是一片半透明。
    ///
    /// 面板边缘挡住光,阴影在接触处的浓度应当是全带最高的,且接触线本身
    /// 有一段实心高度。早期「模糊挖空」实现里,`.blur()` 向下扩散侵入了核心区,
    /// 实测核心区保留率只有 0.55~0.81,于是接触线缺失、剖面中间鼓——
    /// 阴影读起来是浮在面板上方的一条灰带,而不是面板压出来的接触阴影。
    ///
    /// 这条断言直接比对「接触线的高度」与「接触线的浓度」:
    /// 接触线内各行的浓度应当彼此接近(实心),且明显高于接触线之上的第一行
    /// (说明梯度是从接触线上沿才开始衰减的)。
    @Test("面板顶边处有一条实心接触线,其上才是衰减区")
    func topShadowHasSolidContactLine() throws {
        let header = 40
        let (rep, panelTopRow) = try renderPanel(header: header)

        // 接触线覆盖带底部的若干行(自面板顶边往上数)。
        let coreRows = max(1, Int(GoalTopShadowView.coreHeight.rounded(.up)))
        var contact: [Double] = []
        for offset in 0..<coreRows {
            contact.append(rowBrightness(rep, y: panelTopRow - 1 - offset))
        }

        // 接触线内部各行浓度应当接近——实心区域不该有明显梯度。
        // 容差 2.0 吸收抗锯齿抖动。
        for index in 1..<contact.count {
            #expect(
                abs(contact[index] - contact[index - 1]) <= 2.0,
                "接触线内部第 \(index) 行亮度 \(contact[index]) 与上一行 \(contact[index - 1]) 差异过大,接触线不是实心的"
            )
        }

        // 越过接触线之后浓度必须明显下降,证明梯度确实从接触线上沿才开始。
        let aboveCore = rowBrightness(rep, y: panelTopRow - 1 - coreRows)
        #expect(
            aboveCore > contact[0] + 3.0,
            "接触线之上的亮度 \(aboveCore) 与接触线 \(contact[0]) 过于接近,阴影没有形成实心接触线"
        )
    }

    /// 接触线应当是全带**最浓**的一段。
    ///
    /// 真正的投影里,斜率在接触处最陡、浓度在接触处最高。旧实现因为模糊
    /// 侵入核心,峰值反而落到了带的中段,阴影读起来是浮着的。
    @Test("阴影浓度峰值位于面板顶边而非带的中段")
    func topShadowPeakIsAtPanelEdge() throws {
        let header = 40
        let (rep, panelTopRow) = try renderPanel(header: header)

        let bandHeight = Int(GoalTopShadowView.bandHeight)
        var profile: [Double] = []
        for offset in stride(from: bandHeight - 1, through: 0, by: -1) {
            profile.append(rowBrightness(rep, y: panelTopRow - 1 - offset))
        }

        // profile.last 是紧贴面板顶边那一行,profile[0] 是带的上沿。
        let edgeBrightness = profile[profile.count - 1]
        let middleBrightness = profile[profile.count / 2]

        #expect(
            edgeBrightness < middleBrightness,
            "面板顶边亮度 \(edgeBrightness) 未比带中段 \(middleBrightness) 更暗,阴影峰值不在接触处"
        )
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
