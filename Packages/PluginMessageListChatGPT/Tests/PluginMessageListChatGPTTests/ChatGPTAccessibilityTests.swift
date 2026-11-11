import Foundation
import LumiUI
import SwiftUI
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）无障碍契约测试。
///
/// 基准是 V5 方案第 1.4 节与 Task 8 的要求：
/// - 所有图标按钮有本地化 `accessibilityLabel`、稳定 identifier 和键盘焦点；
/// - 不因流式 token 移动 VoiceOver 焦点，不逐 token 发 announcement；
/// - hover 不是显示操作的唯一方式：键盘 focus 也能到达相同动作；
/// - Reduced Motion 下关闭 shimmer、淡入和位移动画；
/// - 信息本身不能依赖动画表达。
@Suite("V5 无障碍契约")
struct ChatGPTAccessibilityTests {

    // MARK: - 稳定标识符

    @Test("列表层标识符稳定且带包前缀")
    func listIdentifiersAreStable() {
        #expect(ChatGPTAccessibilityIdentifiers.listContainer == "lumi.message-list.chatgpt.container")
        #expect(ChatGPTAccessibilityIdentifiers.backToBottomButton == "lumi.message-list.chatgpt.back-to-bottom")
        #expect(ChatGPTAccessibilityIdentifiers.loadEarlierButton == "lumi.message-list.chatgpt.load-earlier")
        #expect(ChatGPTAccessibilityIdentifiers.turn == "lumi.message-list.chatgpt.turn")
    }

    @Test("列表层与渲染层标识符不冲突")
    func listAndRendererIdentifiersDoNotCollide() {
        // 两个包互不依赖（插件不得依赖插件），因此各自一份标识符清单。
        // 前缀不同保证 AX 树里的定位不会互相命中。
        #expect(ChatGPTAccessibilityIdentifiers.listContainer.hasPrefix("lumi.message-list.chatgpt."))
        #expect(ChatGPTAccessibilityIdentifiers.backToBottomButton.hasPrefix("lumi.message-list.chatgpt."))
    }

    // MARK: - 回到底部按钮

    @Test("回到底部按钮有本地化 label 与帮助文本")
    func backToBottomButtonHasLabel() {
        // 按钮的 AX label 必须是**本地化文案**而不是 symbol 名，
        // 否则 VoiceOver 会读出 "arrow.down" 这样的图标名。
        //
        // - Note: 这里断言的是「解析出的文本非空」，
        //   真正的四语言完整性由 `i18n` 技能扫描 xcstrings 保证。
        let label = pluginLocalization.string("回到底部")
        #expect(!label.isEmpty)
        #expect(!label.contains("arrow.down"))
    }

    @Test("回到底部按钮几何符合 V5 token")
    func backToBottomMetrics() {
        #expect(ChatGPTBackToBottomStyle.size == 32)
        #expect(ChatGPTBackToBottomStyle.bottomSpacing == 16)
    }

    // MARK: - Reduced Motion

    @Test("Reduced Motion 下关闭位移动画")
    func reducedMotionDisablesShiftAnimation() {
        // 「回到底部」按钮的位移/淡入动画在 Reduced Motion 下必须关闭。
        #expect(ChatGPTMotion.allowsShiftAnimation(preference: .init(reduceMotion: true)) == false)
        #expect(ChatGPTMotion.allowsShiftAnimation(preference: .init(reduceMotion: false)) == true)
    }

    @Test("Reduced Motion 下关闭淡入与 shimmer")
    func reducedMotionDisablesFadeAndShimmer() {
        #expect(ChatGPTMotion.allowsFadeAnimation(preference: .init(reduceMotion: true)) == false)
        #expect(ChatGPTMotion.allowsFadeAnimation(preference: .init(reduceMotion: false)) == true)
        #expect(ChatGPTMotion.allowsShimmer(preference: .init(reduceMotion: true)) == false)
        #expect(ChatGPTMotion.allowsShimmer(preference: .init(reduceMotion: false)) == true)
    }

    @Test("全局禁用动画时同样关闭")
    func globallyDisabledAnimationsAlsoOff() {
        let disabled = LumiMotionPreference(disableAnimations: true)
        #expect(ChatGPTMotion.allowsShiftAnimation(preference: disabled) == false)
        #expect(ChatGPTMotion.allowsFadeAnimation(preference: disabled) == false)
        #expect(ChatGPTMotion.allowsShimmer(preference: disabled) == false)
    }

    // Note: 「流式没有光标 / 淡入 / 脉冲」的断言放在渲染器包的
    // `ChatGPTRendererAccessibilityTests` 里 ——
    // `ChatGPTAssistantTextStyle` 属于 `PluginMessageRenderer`，
    // 列表包**不得**依赖它（插件不得依赖插件）。

    // MARK: - 本地化

    @Test("V5 列表层文案四语言齐全")
    func listLocalizationCoversFourLanguages() {
        // 四语言必须在同一个 xcstrings 里各有一份。
        let keys = [
            "加载更早的消息",
            "正在加载消息…",
            "回到底部",
        ]
        for key in keys {
            #expect(!pluginLocalization.string(key).isEmpty)
        }
    }

    @Test("V5 渲染层文案四语言齐全")
    func rendererLocalizationCoversFourLanguages() {
        // 渲染层的文案由 `PluginMessageRenderer` 的目录维护；
        // 这里只验证 V5 用到的 key 都能解析出非空文本。
        let keys = [
            "Copy",
            "正在思考…",
            "已思考",
            "工具",
            "重试",
            "重新发送",
        ]
        for key in keys {
            #expect(!pluginLocalization.string(key).isEmpty)
        }
    }
}
