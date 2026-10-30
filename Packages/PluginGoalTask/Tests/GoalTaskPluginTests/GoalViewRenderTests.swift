import Testing
import Foundation
import SwiftUI
import AppKit
@testable import GoalTaskPlugin

/// Goal 插件视图层的渲染级测试。
///
/// ## 为什么要渲染着测
///
/// 视图层的很多约束是「只有渲染出来才看得见」的：行高、内边距、截断、
/// 描边颜色、容器封顶。纯函数测试碰不到这些，而 XCUITest 一条要跑约 60 秒。
/// 这里用 `ImageRenderer` 渲染真实视图后逐像素量，单条约 1 秒，
/// 适合把几何约束钉死。
///
/// ## 空白判定用「相对背景色」而不是「接近白色」
///
/// 任务行的底色是 `orange.opacity(0.075)` 叠在白底上，蓝通道只有 236 左右，
/// 远低于「接近白色」的阈值。按纯白判空白会把**整行**都算成有内容，
/// 断言全部失效。因此这里先渲染一块已知底色做参照，再按色差判空白。
///
/// ## 已知限制
///
/// `ImageRenderer` 不渲染 `ScrollView` 的内容（实测任务列表渲染出来是空的），
/// 因此**列表内部的行布局测不了**，只能测：
/// - 独立渲染的任务行 `TaskRowView`
/// - 独立的阻塞原因卡片 `SidebarBlockedReason`
/// - 列表容器的几何计算（高度封顶等），这部分已抽成纯函数直接断言
@MainActor
@Suite("Goal View Render Tests")
struct GoalViewRenderTests {

    // MARK: - 渲染辅助

    /// 渲染视图并返回位图。
    ///
    /// 统一垫一层白底，模拟行在侧边栏面板上的真实底色。
    /// 不垫白底时半透明底色会叠在**透明**背景上，与「叠白底」的参照色板
    /// 不是同一个颜色空间，比较出来的差值全是噪声。
    ///
    /// 走 `NSBitmapImageRep` 而不是 `CGContext.draw`：后者在自建上下文里会把图像
    /// 上下翻转，量出来的上下会整个反过来，结论完全相反。
    private func render(
        _ view: some View,
        width: Int,
        height: Int
    ) throws -> NSBitmapImageRep {
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

    /// 取指定坐标的 RGB 分量。
    private func rgb(_ rep: NSBitmapImageRep, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        guard let color = rep.colorAt(x: x, y: y) else { return (0, 0, 0) }
        return (
            Int((color.redComponent * 255).rounded()),
            Int((color.greenComponent * 255).rounded()),
            Int((color.blueComponent * 255).rounded())
        )
    }

    /// 任务行底色的参照值。
    ///
    /// 直接渲染一块同色底板取样，避免把「橙色半透明」的期望值硬编码进测试——
    /// 换主题或换底色时，测试会因为参照值跟着变而继续成立。
    private func rowBackground() throws -> (r: Int, g: Int, b: Int) {
        let swatch = Color.orange.opacity(0.075)
            .frame(width: 20, height: 20)

        let rep = try render(swatch, width: 20, height: 20)
        return rgb(rep, x: 10, y: 10)
    }

    /// 该像素相对底色是否有内容（色差超过阈值即认为画了东西）。
    private func hasContent(
        _ rep: NSBitmapImageRep,
        background: (r: Int, g: Int, b: Int),
        x: Int,
        y: Int,
        tolerance: Int = 6
    ) -> Bool {
        let c = rgb(rep, x: x, y: y)
        return abs(c.r - background.r) > tolerance
            || abs(c.g - background.g) > tolerance
            || abs(c.b - background.b) > tolerance
    }

    /// 指定横向区间内相对底色是否有内容。
    private func hasContent(
        _ rep: NSBitmapImageRep,
        background: (r: Int, g: Int, b: Int),
        xRange: Range<Int>,
        y: Int,
        tolerance: Int = 6
    ) -> Bool {
        for x in xRange {
            if hasContent(rep, background: background, x: x, y: y, tolerance: tolerance) {
                return true
            }
        }
        return false
    }

    /// 该像素是否是「文字墨迹」——明显比底色暗。
    ///
    /// 用亮度而不是「与底色有色差」来判定：描边是橙色（与底色同色系、亮度接近），
    /// 文字是近黑色，两者用同一个阈值分不开；按亮度分得很干净。
    private func hasInk(
        _ rep: NSBitmapImageRep,
        background: (r: Int, g: Int, b: Int),
        x: Int,
        y: Int,
        threshold: Int = 60
    ) -> Bool {
        rgb(rep, x: x, y: y).r < background.r - threshold
    }

    /// 墨迹的垂直范围（上下沿），没有墨迹时返回 nil。
    private func inkVerticalExtent(
        _ rep: NSBitmapImageRep,
        background: (r: Int, g: Int, b: Int),
        threshold: Int = 60
    ) -> (minY: Int, maxY: Int)? {
        var minY: Int?
        var maxY: Int?
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if hasInk(rep, background: background, x: x, y: y, threshold: threshold) {
                    minY = min(minY ?? y, y)
                    maxY = max(maxY ?? y, y)
                }
            }
        }
        guard let minY, let maxY else { return nil }
        return (minY, maxY)
    }

    /// 整行内最靠右的墨迹列（-1 表示没有文字）。
    ///
    /// 逐列扫全高，而不是只看某一条扫描线：文字的墨迹分布不均，
    /// 只看一条线会漏掉「有字但那条线上没墨」的情况。
    private func rightmostInkColumn(
        _ rep: NSBitmapImageRep,
        background: (r: Int, g: Int, b: Int),
        threshold: Int = 60
    ) -> Int {
        for x in stride(from: rep.pixelsWide - 1, through: 0, by: -1) {
            for y in 0..<rep.pixelsHigh {
                if hasInk(rep, background: background, x: x, y: y, threshold: threshold) {
                    return x
                }
            }
        }
        return -1
    }

    /// 构造一个任务展示项。
    private func makeItem(
        title: String,
        status: GoalTask.TaskStatus = .pending,
        parallelGroup: String? = nil
    ) -> GoalTaskDisplayItem {
        GoalTaskDisplayItem(
            from: GoalTask(
                goalId: "g",
                title: title,
                status: status,
                order: 0,
                parallelGroup: parallelGroup
            )
        )
    }

    // MARK: - 任务行几何

    /// 任务行高度必须正好是 `SidebarView.rowHeight`。
    ///
    /// 行高是整份几何的基准：容器高度按 `行数 × 行高 + 行距 + 内边距` 算，
    /// 行高一变，容器封顶点与实际能显示的行数全变。
    @Test("任务行高度为 30pt")
    func taskRowHeightIsThirtyPoints() throws {
        let row = TaskRowView(displayItem: makeItem(title: "侦察与基线"))
            .frame(width: 200)

        let rep = try render(row, width: 200, height: 30)
        #expect(rep.pixelsHigh == Int(SidebarView.rowHeight))
    }

    /// 任务行的底色是橙色半透明、描边是更深的橙色。
    ///
    /// 底色写错不会让任何功能挂掉，但会让「进行中的任务」失去视觉标识，
    /// 属于只能靠渲染发现的回归。
    @Test("任务行底色与描边为橙色系")
    func taskRowUsesOrangeSurface() throws {
        let background = try rowBackground()
        let row = TaskRowView(displayItem: makeItem(title: "任务"))
            .frame(width: 200)

        let rep = try render(row, width: 200, height: 30)

        // 行内空白处应当就是底色本身。
        let interior = rgb(rep, x: 150, y: 15)
        #expect(
            abs(interior.r - background.r) <= 3
                && abs(interior.g - background.g) <= 3
                && abs(interior.b - background.b) <= 3,
            "行内底色 \(interior) 与参照底色 \(background) 不一致"
        )

        // 描边比底色更深一档的橙色：蓝通道被压得最明显。
        let border = rgb(rep, x: 0, y: 15)
        #expect(
            border.b < background.b - 6,
            "描边蓝通道 \(border.b) 与底色 \(background.b) 差异过小,描边没画出来"
        )
        #expect(
            border.r >= background.r - 2,
            "描边红通道 \(border.r) 不该低于底色 \(background.r)"
        )
    }

    /// 状态图标左侧留 8pt 内边距。
    ///
    /// 内边距被改小会让图标贴到描边上,改大会让标题起点漂移。
    @Test("任务行状态图标从 8pt 内边距处开始")
    func taskRowIconStartsAtEightPointInset() throws {
        let background = try rowBackground()
        let row = TaskRowView(displayItem: makeItem(title: "任务"))
            .frame(width: 200)

        let rep = try render(row, width: 200, height: 30)

        // 图标占据 x = 8...22；x=3 处只有底色，不该有图标像素。
        #expect(
            !hasContent(rep, background: background, x: 3, y: 15),
            "状态图标越过了 8pt 内边距,x=3 处已有内容"
        )
        // 图标本身必须在 x=8 之后出现，确認图标确实画出来了。
        #expect(
            hasContent(rep, background: background, xRange: 8..<22, y: 15),
            "x=8...22 处没有状态图标"
        )
    }

    /// 长标题必须被截断到行内，不能把布局撑破。
    ///
    /// `TaskRowView` 给标题加了 `.lineLimit(1)` + `.truncationMode(.tail)`，
    /// 一旦这行修饰被去掉，长标题会把 `Spacer` 挤没、顶出圆角容器。
    @Test("长标题被截断到行右边缘")
    func longTitleIsTruncatedAtRowEdge() throws {
        let background = try rowBackground()

        let short = TaskRowView(displayItem: makeItem(title: "短"))
            .frame(width: 200)
        let long = TaskRowView(
            displayItem: makeItem(title: String(repeating: "很长的任务标题", count: 12))
        )
        .frame(width: 200)

        let shortRep = try render(short, width: 200, height: 30)
        let longRep = try render(long, width: 200, height: 30)

        let shortRight = rightmostInkColumn(shortRep, background: background)
        let longRight = rightmostInkColumn(longRep, background: background)

        // 短标题右侧留白。
        #expect(
            shortRight < 100,
            "短标题右缘 \(shortRight) 太靠右,不该延伸到行中部"
        )
        // 长标题铺满了整行的文字区，而不是被挤在开头。
        #expect(
            longRight > shortRight + 60,
            "长标题右缘 \(longRight) 与短标题 \(shortRight) 差距过小,长标题没铺开"
        )
        // 长标题没有溢出行的右内边距（x=192）。
        #expect(
            longRight < 195,
            "长标题右缘 \(longRight) 溢出了行的右内边距"
        )

        // 关键：`.lineLimit(1)` 还在时文字只占一行高。
        // 一旦这行修饰被去掉，文字会换行铺满整行、再被 `.frame(height: 30)` 纵向裁掉，
        // 用户看到的是「标题少了几截」——这才是去掉截断修饰的真实症状。
        let extent = try #require(
            inkVerticalExtent(longRep, background: background),
            "长标题没有渲染出任何文字"
        )
        #expect(
            extent.maxY - extent.minY <= 20,
            "长标题墨迹纵向跨了 \(extent.maxY - extent.minY)pt,说明文字换行了(.lineLimit(1) 失效)"
        )
    }

    // MARK: - 阻塞原因卡片

    /// 阻塞原因卡片高度固定为 `SidebarView.blockedReasonCardHeight`。
    ///
    /// 高度写死是为了让侧边栏总高可算；卡片一旦变高，标题栏 + 卡片 + 分割线
    /// + 任务列表的排布就会错位。
    @Test("阻塞原因卡片高度为 40pt")
    func blockedReasonCardHeightIsFortyPoints() throws {
        let card = SidebarBlockedReason(reason: "缺少鉴权")
            .frame(width: 200)

        let rep = try render(card, width: 200, height: 40)
        #expect(rep.pixelsHigh == Int(SidebarView.blockedReasonCardHeight))
    }

    // MARK: - 容器高度计算

    /// 容器高度 = 行数 × 行高 + (行数-1) × 行距 + 上下内边距。
    @Test("容器高度按行数计算")
    func containerHeightFollowsRowCount() {
        // 0 个任务 → 不占高度
        #expect(SidebarView.taskListHeight(forTaskCount: 0) == 0)

        // 1 个任务 = 30 + 0 + 8
        #expect(SidebarView.taskListHeight(forTaskCount: 1) == 38)

        // 3 个任务 = 3×30 + 2×4 + 8 = 106
        #expect(SidebarView.taskListHeight(forTaskCount: 3) == 106)

        // 5 个任务 = 5×30 + 4×4 + 8 = 174 → 超过 160 上限
        #expect(SidebarView.taskListHeight(forTaskCount: 5) == 160)
    }

    /// 任务过多时容器封顶，不随任务数无限增高。
    ///
    /// 这条约束决定了任务列表最多露出几行；越界会让侧边栏把整个聊天面板挤扁。
    /// 它此前没有任何测试覆盖。
    @Test("容器高度在 160pt 封顶")
    func containerHeightIsCapped() {
        let cap = SidebarView.taskListHeight(forTaskCount: 5)
        #expect(cap == 160, "5 个任务时应封顶到 160pt,实际 \(cap)")

        // 再多任务也不变高
        for count in [6, 10, 50, 200] {
            #expect(
                SidebarView.taskListHeight(forTaskCount: count) == 160,
                "\(count) 个任务时容器高度应为 160pt"
            )
        }
    }

    /// 刚好不超上限时按内容高度走，不提前封顶。
    @Test("未超上限时按内容高度")
    func containerHeightFollowsContentBelowCap() {
        // 4 个任务 = 4×30 + 3×4 + 8 = 140，未超 160
        #expect(SidebarView.taskListHeight(forTaskCount: 4) == 140)
    }
}
