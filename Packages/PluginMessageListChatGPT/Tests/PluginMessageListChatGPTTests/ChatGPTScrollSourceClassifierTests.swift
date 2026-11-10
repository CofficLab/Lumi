import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListChatGPT

/// V5（ChatGPT）滚动来源分类器测试。
///
/// 基准是 V5 方案 Task 6 的要求：
/// - 只有真实用户滚动能改变 following；
/// - 程序化滚动期间的用户输入要被忽略；
/// - 输入框内的按键不算消息列表滚动。
@Suite("V5 滚动来源分类")
struct ChatGPTScrollSourceClassifierTests {

    @Test("滚轮、触摸与滚动条是用户来源")
    func wheelTouchScrollbarAreUser() {
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .scrollWheel)
        ) == .user)
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .touch)
        ) == .user)
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .scrollbar)
        ) == .user)
    }

    @Test("程序化滚动是 programmatic 来源")
    func programmaticIsProgrammatic() {
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .programmatic)
        ) == .programmatic)
    }

    @Test("布局类事件是 layout 来源")
    func layoutEventsAreLayout() {
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .documentFrameChange)
        ) == .layout)
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .liveResize)
        ) == .layout)
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .layout)
        ) == .layout)
    }

    @Test("程序化作用域内的用户输入被忽略")
    func programmaticScopeOverridesUserInput() {
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(
                kind: .scrollWheel,
                isProgrammaticScopeActive: true
            )
        ) == .programmatic)
    }

    @Test("输入框内的滚轮不算消息列表滚动")
    func editableTargetIsNotUserScroll() {
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .scrollWheel, isEditableTarget: true)
        ) == .layout)
    }

    @Test("滚动键属于用户来源")
    func scrollKeysAreUser() {
        for key in ["ArrowUp", "ArrowDown", "PageUp", "PageDown", "Home", "End", " "] {
            #expect(ChatGPTScrollSourceClassifier.isTimelineScrollKey(key))
            #expect(ChatGPTScrollSourceClassifier.classify(
                ChatGPTScrollSourceInput(kind: .key, key: key)
            ) == .user)
        }
    }

    @Test("非滚动键属于布局来源")
    func nonScrollKeysAreLayout() {
        for key in ["a", "b", "Enter", "Tab", "Escape"] {
            #expect(!ChatGPTScrollSourceClassifier.isTimelineScrollKey(key))
            #expect(ChatGPTScrollSourceClassifier.classify(
                ChatGPTScrollSourceInput(kind: .key, key: key)
            ) == .layout)
        }
    }

    @Test("输入框内的按键不算消息列表滚动")
    func editableTargetKeyIsLayout() {
        #expect(ChatGPTScrollSourceClassifier.classify(
            ChatGPTScrollSourceInput(kind: .key, key: "ArrowUp", isEditableTarget: true)
        ) == .layout)
    }

    @Test("只接受同一 window 与同一滚动视图的事件")
    func eventFiltering() {
        #expect(ChatGPTScrollSourceClassifier.shouldAcceptUserEvent(
            eventWindowID: 1,
            targetWindowID: 1,
            eventScrollViewID: 2,
            targetScrollViewID: 2
        ))
        // 不同 window：拒绝。
        #expect(!ChatGPTScrollSourceClassifier.shouldAcceptUserEvent(
            eventWindowID: 1,
            targetWindowID: 9,
            eventScrollViewID: 2,
            targetScrollViewID: 2
        ))
        // 不同滚动视图：拒绝。
        #expect(!ChatGPTScrollSourceClassifier.shouldAcceptUserEvent(
            eventWindowID: 1,
            targetWindowID: 1,
            eventScrollViewID: 2,
            targetScrollViewID: 8
        ))
    }

    @Test("程序化作用域用嵌套计数")
    func programmaticScopeUsesNesting() {
        var scope = ChatGPTProgrammaticScrollScope()
        #expect(!scope.isActive)

        scope.begin()
        scope.begin()
        #expect(scope.isActive)

        scope.end()
        #expect(scope.isActive)

        scope.end()
        #expect(!scope.isActive)

        // 多余的 end 不能让深度变成负数。
        scope.end()
        #expect(!scope.isActive)
    }

    @Test("withScope 自动配对")
    func withScopeBalances() {
        var scope = ChatGPTProgrammaticScrollScope()
        var observedInsideScope = false
        scope.withScope {
            // 闭包内不能直接访问 scope（独占访问冲突），用局部变量回传。
            observedInsideScope = true
        }
        #expect(observedInsideScope)
        #expect(!scope.isActive)
    }
}
