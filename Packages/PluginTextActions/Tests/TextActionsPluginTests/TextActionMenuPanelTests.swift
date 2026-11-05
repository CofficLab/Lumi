import AppKit
import SwiftUI
import Testing
@testable import TextActionsPlugin

// MARK: - 浮层状态机

@MainActor
@Suite("Text Actions 浮层状态机")
struct TextActionMenuModelTests {

    @Test("初始状态是动作条")
    func initialStateIsActions() {
        let model = TextActionMenuModel()
        #expect(model.state == .actions)
        #expect(model.text.isEmpty)
    }

    @Test("perform 转发给注入的处理器")
    func performForwardsToHandler() {
        let model = TextActionMenuModel()
        var received: [TextAction] = []
        model.onPerform = { received.append($0) }

        model.perform(.copy)
        model.perform(.search)
        model.perform(.translate)

        #expect(received == [.copy, .search, .translate])
    }

    @Test("状态切换触发 onStateChange")
    func stateChangeNotifies() {
        let model = TextActionMenuModel()
        var states: [TextActionMenuModel.State] = []
        model.onStateChange = { states.append($0) }

        model.state = .translating
        model.state = .translated("你好")
        model.state = .failed("network")

        #expect(states == [.translating, .translated("你好"), .failed("network")])
    }

    @Test("文本变化不自动重置状态——由控制器决定何时回到动作条")
    func textChangeDoesNotResetState() {
        let model = TextActionMenuModel()
        model.state = .translated("你好")

        model.text = "new selection"

        // 设计约束：model 是纯状态载体，状态重置只发生在控制器的
        // 「新文本 / 全新展示」分支里，避免同文本重复 show 打断翻译。
        #expect(model.state == .translated("你好"))
    }
}

// MARK: - 浮层视图渲染冒烟

/// 用 ImageRenderer 把浮层各状态真实渲染成位图，断言「确实画出了内容」。
///
/// 浮层出现在其他应用上方、不抢焦点，XCUITest 难以稳定驱动（需要
/// 真实的跨应用划词与辅助功能授权），因此视图层用渲染冒烟覆盖：
/// 每个状态都必须渲染出非空墨迹，防止视图在预览之外的设备上空屏。
@MainActor
@Suite("Text Actions 浮层渲染")
struct TextActionMenuViewRenderTests {

    /// 垫白底渲染（浮层用 regularMaterial，半透明，必须垫底色才有稳定参照）。
    private func renderInkCount(state: TextActionMenuModel.State) throws -> Int {
        let model = TextActionMenuModel()
        model.text = "hello world"
        model.state = state

        let renderer = ImageRenderer(
            content: ZStack {
                Color.white
                TextActionMenuView(model: model)
            }
            .frame(width: 320, height: 220)
        )
        renderer.scale = 1
        renderer.isOpaque = false

        let cgImage = try #require(renderer.cgImage, "ImageRenderer 未产出图像")
        let rep = NSBitmapImageRep(cgImage: cgImage)

        // 统计明显比白底暗的像素（文字 / 图标墨迹）。
        var ink = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                if let color = rep.colorAt(x: x, y: y),
                   color.redComponent < 0.6 {
                    ink += 1
                }
            }
        }
        return ink
    }

    @Test("动作条渲染出内容")
    func actionsStateRendersContent() throws {
        #expect(try renderInkCount(state: .actions) > 0)
    }

    @Test("复制反馈渲染出内容")
    func copiedStateRendersContent() throws {
        #expect(try renderInkCount(state: .copied) > 0)
    }

    @Test("翻译结果渲染出内容")
    func translatedStateRendersContent() throws {
        #expect(try renderInkCount(state: .translated("你好，世界")) > 0)
    }

    @Test("翻译失败渲染出内容")
    func failedStateRendersContent() throws {
        #expect(try renderInkCount(state: .failed("network error")) > 0)
    }
}

// MARK: - 浮层面板配置

@MainActor
@Suite("Text Actions 浮层面板配置")
struct TextActionMenuPanelTests {

    @Test("面板不抢焦点、不在后台隐藏")
    func panelIsNonActivatingAndPersistent() {
        let panel = TextActionMenuPanel()

        // 这几条是划词浮层的生死线：抢焦点会打断用户在其他应用里的
        // 输入状态；hidesOnDeactivate 为 true 时浮层随 Lumi 进后台立即消失。
        #expect(panel.canBecomeKey == false)
        #expect(panel.canBecomeMain == false)
        #expect(panel.hidesOnDeactivate == false)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.styleMask.contains(.borderless))
    }

    @Test("面板跨 Space 且可叠加在全屏应用上")
    func panelCollectionBehavior() {
        let panel = TextActionMenuPanel()

        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
    }
}
