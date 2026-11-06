import AppKit
import LumiUI
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 输入框「悬浮卡片」的渲染级测试。
///
/// ## 为什么要渲染着测
///
/// 卡片感来自三件只能靠像素确认的事:卡片与聊天区之间留出了间距、四角是圆角、
/// 卡片底下压着一层柔和投影。任一条写错(比如圆角退回 0、投影被上层操作栏盖住、
/// 间距被改回 0)都不会让任何功能挂掉,但用户一眼就会看出输入框「塌」回了原来
/// 那块扁平色带。这里逐像素量,把「悬浮」这条视觉契约钉死。
@MainActor
@Suite("Composer Surface Tests")
struct ComposerSurfaceTests {

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

    /// 某点的灰度(0-255)。
    private func brightness(_ rep: NSBitmapImageRep, x: Int, y: Int) -> Int {
        guard let color = rep.colorAt(x: x, y: y) else { return 255 }
        return Int((color.redComponent * 255).rounded())
    }

    /// 某点是否落在标记色上。
    private func isMarker(_ rep: NSBitmapImageRep, x: Int, y: Int) -> Bool {
        guard let color = rep.colorAt(x: x, y: y) else { return false }
        return color.redComponent > 0.5
            && color.redComponent - color.greenComponent > 0.3
            && color.redComponent - color.blueComponent > 0.3
    }

    /// 构造一张与真实输入框同尺寸的卡片。
    ///
    /// 真实编辑器是 `NSViewRepresentable`,`ImageRenderer` 渲染不出它的内容,
    /// 这里用同尺寸的占位内容代替,卡片外观走的是同一套 `composerSurface()`。
    private func plainCard() -> some View {
        Color.clear
            .frame(width: 160, height: 40)
            .composerSurface()
    }

    /// 带标记色的卡片:用一块纯色块精确定位卡片边缘。
    ///
    /// 卡片表面与聊天区底色只差几个色阶,靠亮度差找边缘既不稳也咬不住
    /// (把间距改成 0 仍会「通过」),标记色则一眼可辨。
    private func markedCard() -> some View {
        Color.red
            .frame(width: 160, height: 40)
            .composerSurface()
    }

    /// 带标记色、且走完整生产内边距链路的卡片。
    ///
    /// 标记色块被 `composerContentInsets()` 包住,于是标记色的上缘 = 卡片内
    /// 文字的上缘;标记色块被 `composerSurface()` 包住,于是卡片上缘在标记色
    /// 上缘之上 `contentTopInset` 处。两者的差即内部上内边距。
    private func insetMarkedCard() -> some View {
        Color.red
            .frame(width: 160, height: 40)
            .composerContentInsets()
            .composerSurface()
    }

    /// 把卡片摆到画布左上角。
    private func placed(_ card: some View, canvas: Int) -> some View {
        card.frame(width: CGFloat(canvas), height: 120, alignment: .topLeading)
    }

    // MARK: - Tests

    /// 卡片与聊天区左右边缘之间必须留出间距。
    ///
    /// 贴着边缘的输入框读起来是「聊天区的一部分」,留出间距才有「浮起来」的观感。
    /// 这里用标记色定位卡片左缘:卡片表面与聊天区底色只差几个色阶,靠亮度差找
    /// 边缘既不稳也咬不住(把间距改成 0 仍会「通过」)。
    ///
    /// 期望值 14 是**写死的数字**,不是从 `ComposerLayout` 反推的:
    /// 反推等于拿实现校验实现,常量一改断言跟着改,永远不会失败。
    /// 写死之后,任何人动这块间距都必须同时想清楚「要不要改这里」。
    ///
    /// - Note: 上边缘**不**留间距(`outerTopInset == 0`),输入卡片紧贴上方内容。
    @Test("输入框卡片与上下左右边缘留出间距")
    func cardIsInsetFromEdges() throws {
        let canvas = 300
        let rep = try render(placed(markedCard(), canvas: canvas), width: canvas, height: 120)

        // 卡片中部那一行上,标记色的起点即卡片左缘。
        let row = 0 + 20
        var markerStart: Int?
        for x in 0..<rep.pixelsWide where isMarker(rep, x: x, y: row) {
            markerStart = x
            break
        }
        let start = try #require(markerStart, "卡片左缘没有找到标记色")

        #expect(
            abs(start - 14) <= 1,
            "卡片左缘落在 x=\(start),与预期的 14 不符"
        )

        // 卡片内部那一列上,标记色的起点即卡片上缘。
        let column = 14 + 30
        var markerTop: Int?
        for y in 0..<rep.pixelsHigh where isMarker(rep, x: column, y: y) {
            markerTop = y
            break
        }
        let top = try #require(markerTop, "卡片上缘没有找到标记色")

        #expect(
            abs(top - 0) <= 1,
            "卡片上缘落在 y=\(top),与预期的 0 不符"
        )
    }

    /// 卡片四角必须是圆角,不能是直角。
    ///
    /// 16pt 圆角下,紧贴包围盒角内侧 1pt 的位置落在圆弧之外,应当仍是聊天区底色。
    @Test("输入框卡片四角为圆角")
    func cardCornersAreRounded() throws {
        let canvas = 300
        let rep = try render(placed(plainCard(), canvas: canvas), width: canvas, height: 120)

        // 与上一条同理:期望几何写死,不被实现常量带跑。
        let left = 14
        let top = 0

        // 角点处:应是底色(圆弧之外)。
        let corner = brightness(rep, x: left + 1, y: top + 1)
        // 卡片内部(远离圆角):应是卡片表面。
        let interior = brightness(rep, x: left + 30, y: top + 20)
        #expect(
            abs(corner - interior) >= 3,
            "角点亮度 \(corner) 与卡片内部 \(interior) 过于接近,圆角没有生效"
        )
    }

    /// 卡片底下必须压着一层柔和投影。
    ///
    /// 投影是「浮起来」最主要的来源:卡片下缘紧邻的一行应当比远处的底色更暗,
    /// 再往下则逐渐衰减回底色。
    @Test("输入框卡片下方有柔和投影")
    func cardCastsSoftShadowBelow() throws {
        let canvas = 300
        let rep = try render(placed(plainCard(), canvas: canvas), width: canvas, height: 120)

        let top = 0
        let cardBottom = top + 40

        // 远处底色(画布底部)。
        let far = brightness(rep, x: 10, y: 115)
        // 卡片下缘紧邻的一行:应当被投影压暗。
        let nearEdge = brightness(rep, x: 10, y: cardBottom + 1)
        #expect(
            nearEdge < far,
            "卡片下缘亮度 \(nearEdge) 不低于远处底色 \(far),投影没有画出来"
        )
        // 投影是渐隐的:再往下几行应当回到底色附近。
        let further = brightness(rep, x: 10, y: cardBottom + 12)
        #expect(
            further > nearEdge,
            "投影没有随距离衰减(近 \(nearEdge) / 远 \(further))"
        )
    }

    /// 卡片**内部**必须留出内容内边距:文字不能顶到卡片边缘。
    ///
    /// 这条与「卡片与聊天区之间的外间距」是两回事,曾经被一起改掉:
    /// 有人为了去掉卡片上方的空隙,把 `outerTopInset` 与 `contentTopInset`
    /// 一并清零,结果文字直接贴上卡片上缘,像被裁掉一半。
    ///
    /// 量法:标记色块代表「文字」,被 `composerContentInsets()` 包住,故标记色
    /// 上缘 = 文字上缘;再被 `composerSurface()` 包住,卡片上缘 = 标记色上缘
    /// 减去内部上内边距。两者之差即内部上内边距。
    ///
    /// 卡片上缘在**标记色块正上方**那一列量:那里没有标记色干扰,而卡片表面
    /// (面板色,深)与画布底色(白)、投影(浅灰)都差得开,取「第一处明显变暗的行」
    /// 即卡片上缘。
    ///
    /// 期望值 10 是**写死的数字**,不从 `ComposerLayout` 反推 —— 反推等于拿
    /// 实现校验实现,常量一改断言跟着改,永远不会失败。
    @Test("输入框卡片内部保留内容内边距")
    func cardKeepsContentInsets() throws {
        let canvas = 300
        let rep = try render(placed(insetMarkedCard(), canvas: canvas), width: canvas, height: 120)

        // 标记色块左侧那一列:标记色的起点即「文字」上缘。
        let textColumn = 14 + 30
        var textTop: Int?
        for y in 0..<rep.pixelsHigh where isMarker(rep, x: textColumn, y: y) {
            textTop = y
            break
        }
        let text = try #require(textTop, "卡片内没有找到标记色")

        // 标记色块正上方那一列:第一处明显变暗的行即卡片上缘。
        //
        // 列号 100 落在「标记色块之内、卡片之内」,既避开两侧圆角,又正好在
        // 标记色块正上方 —— 该列 y < 标记色上缘 的部分全是卡片表面。
        //
        // 阈值取 150:画布白底 255、投影最深处约 204,卡片表面约 37,
        // 三者分得开,不会把投影误认成卡片。
        let edgeColumn = 100
        var cardTop: Int?
        for y in 0..<text where brightness(rep, x: edgeColumn, y: y) < 150 {
            cardTop = y
            break
        }
        let edge = try #require(cardTop, "没有找到卡片上缘")

        let inset = text - edge
        #expect(
            abs(inset - 10) <= 1,
            "卡片内部上内边距为 \(inset),与预期的 10 不符"
        )
    }
}
