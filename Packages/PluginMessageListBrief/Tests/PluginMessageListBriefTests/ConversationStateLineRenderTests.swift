import AppKit
import Foundation
import SwiftUI
import Testing
@testable import PluginMessageListBrief

/// §6 底部状态卡「始终一行」的渲染级测试。
///
/// ## 为什么用「高度」而不是「像素」来判行数
///
/// 状态卡左下角是 7% 透明度的品牌色底，标题文字与底色的明度差极小
/// （实测两者亮度都在 0.9 附近），逐像素找「文字墨迹」既不稳也不可复现。
/// 而**卡片高度**与颜色完全无关：两行版式把高度写死成 46pt
/// （30pt 双行文字 + 上下各 8pt 内边距），单行版式只需要一行文字的高度。
/// 渲染出来的位图高度因此就是「它到底排了几行」的直接证据。
///
/// ## 已知限制
///
/// `ImageRenderer` 渲染的是视图的**理想尺寸**，所以这里必须不套固定高度的
/// `.frame(height:)`，否则量到的永远是套上去的那个值。
@MainActor
@Suite("§6 状态卡单行渲染测试")
struct ConversationStateLineRenderTests {
    private let conversationID = UUID()

    // MARK: - 渲染辅助

    /// 渲染状态卡并返回位图。
    ///
    /// `detail` 决定卡片有没有第二行内容：`nil` 表示「这个阶段没有细节」。
    private func renderStatusCard(detail: String?) throws -> NSBitmapImageRep {
        let vm = ConversationStateVM()
        vm.updateSelectedConversation(conversationID)
        vm.update(
            activity: AgentActivityProjection(
                phase: .executingTool,
                title: "正在执行",
                detail: detail
            ),
            for: conversationID
        )

        let renderer = ImageRenderer(
            content: ConversationStateView(stateVM: vm)
                .frame(width: 360)
        )
        renderer.scale = 1
        renderer.isOpaque = false

        let cgImage = try #require(renderer.cgImage, "ImageRenderer 未产出图像")
        return NSBitmapImageRep(cgImage: cgImage)
    }

    // MARK: - 用例

    @Test("状态卡高度只容得下一行文字")
    func cardHeightFitsSingleLine() throws {
        let rep = try renderStatusCard(detail: "正在读取 Sources/App.swift")
        let height = rep.pixelsHigh

        #expect(
            height < 40,
            """
            状态卡应恒为一行，渲染高度应在一行文字的量级（约 30pt），\
            但实测 \(height)pt —— 这是两行版式（46pt）留下的高度。
            """
        )
        #expect(
            height >= 24,
            "状态卡高度 \(height)pt 过矮，一行 12pt 标题加内边距至少需要约 24pt"
        )
    }

    @Test("没有细节时状态卡高度不变")
    func cardHeightStableWithoutDetail() throws {
        let withDetail = try renderStatusCard(detail: "正在读取 Sources/App.swift")
        let withoutDetail = try renderStatusCard(detail: nil)

        #expect(
            withDetail.pixelsHigh == withoutDetail.pixelsHigh,
            """
            有无细节时卡片高度应一致（细节合并进同一行），\
            实测 \(withDetail.pixelsHigh)pt vs \(withoutDetail.pixelsHigh)pt。
            """
        )
    }
}
