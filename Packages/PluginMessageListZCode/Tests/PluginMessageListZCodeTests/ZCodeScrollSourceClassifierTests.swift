import CoreGraphics
import Foundation
import Testing
@testable import PluginMessageListZCode

/// V4（ZCode）滚动来源分类契约测试。
///
/// 基准是 ZCode 3.15.1 的 `packages/ui/src/v4/timelineScrollAnchor.ts`：
/// - 只有**真实用户滚动输入**可以改变 `following`；
/// - 程序化贴底、terminal 折叠、virtualizer 测高补偿产生的 scroll 事件
///   只更新几何账目；
/// - 事件优先级：显式 programmatic > 当前滚动视图上的真实用户输入 > layout。
///
/// - Important: 不能把所有 `boundsDidChange` 都当作用户滚动。
@Suite("ZCode 滚动来源分类")
struct ZCodeScrollSourceClassifierTests {

    // MARK: - 用户输入

    @Test("滚轮滚动是用户输入")
    func wheelIsUserInput() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .scrollWheel, deltaY: 12, isEditableTarget: false)
            ) == .user
        )
    }

    @Test("触摸滚动是用户输入")
    func touchIsUserInput() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .touch, deltaY: -20, isEditableTarget: false)
            ) == .user
        )
    }

    @Test("键盘滚动是用户输入")
    func keyboardIsUserInput() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .key, key: "ArrowDown", isEditableTarget: false)
            ) == .user
        )
    }

    @Test("滚动条拖动是用户输入")
    func scrollbarDragIsUserInput() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .scrollbar, isEditableTarget: false)
            ) == .user
        )
    }

    @Test("输入框内的光标键不算 timeline 滚动")
    func cursorKeysInEditableTargetAreNotUserScroll() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .key, key: "ArrowDown", isEditableTarget: true)
            ) != .user
        )
    }

    // MARK: - 非用户输入

    @Test("程序化滚动不是用户输入")
    func programmaticIsNotUser() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .programmatic, isEditableTarget: false)
            ) == .programmatic
        )
    }

    @Test("布局变化不是用户输入")
    func layoutIsNotUser() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .layout, isEditableTarget: false)
            ) == .layout
        )
    }

    @Test("文档高度变化是布局来源")
    func documentGrowthIsLayout() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .documentFrameChange, isEditableTarget: false)
            ) == .layout
        )
    }

    @Test("live resize 是布局来源")
    func liveResizeIsLayout() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(kind: .liveResize, isEditableTarget: false)
            ) == .layout
        )
    }

    // MARK: - 优先级

    @Test("显式 programmatic 优先于用户输入")
    func explicitProgrammaticWinsOverUserInput() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(
                    kind: .scrollWheel,
                    deltaY: 12,
                    isEditableTarget: false,
                    isProgrammaticScopeActive: true
                )
            ) == .programmatic
        )
    }

    @Test("没有显式作用域时用户输入胜出")
    func userInputWinsWithoutProgrammaticScope() {
        #expect(
            ZCodeScrollSourceClassifier.classify(
                ZCodeScrollSourceInput(
                    kind: .scrollWheel,
                    deltaY: 12,
                    isEditableTarget: false,
                    isProgrammaticScopeActive: false
                )
            ) == .user
        )
    }

    // MARK: - 作用域

    @Test("程序化作用域进入与退出会被正确记录")
    func programmaticScopeIsTracked() {
        var scope = ZCodeProgrammaticScrollScope()

        #expect(!scope.isActive)

        scope.begin()
        #expect(scope.isActive)

        scope.end()
        #expect(!scope.isActive)
    }

    @Test("嵌套作用域只在最外层结束时才退出")
    func nestedScopeEndsAtOutermost() {
        var scope = ZCodeProgrammaticScrollScope()

        scope.begin()
        scope.begin()
        scope.end()
        #expect(scope.isActive)

        scope.end()
        #expect(!scope.isActive)
    }

    @Test("多余的 end 不会让作用域变成负数")
    func extraEndDoesNotUnderflow() {
        var scope = ZCodeProgrammaticScrollScope()

        scope.end()
        scope.end()
        #expect(!scope.isActive)

        scope.begin()
        #expect(scope.isActive)
    }

    // MARK: - 过滤

    @Test("不同 window 的用户事件被忽略")
    func eventsFromOtherWindowAreIgnored() {
        #expect(
            ZCodeScrollSourceClassifier.shouldAcceptUserEvent(
                eventWindowID: 1,
                targetWindowID: 2,
                eventScrollViewID: 10,
                targetScrollViewID: 10
            ) == false
        )
    }

    @Test("不同滚动视图的用户事件被忽略")
    func eventsFromOtherScrollViewAreIgnored() {
        #expect(
            ZCodeScrollSourceClassifier.shouldAcceptUserEvent(
                eventWindowID: 1,
                targetWindowID: 1,
                eventScrollViewID: 10,
                targetScrollViewID: 20
            ) == false
        )
    }

    @Test("同 window 同滚动视图的用户事件被接受")
    func eventsFromSameTargetAreAccepted() {
        #expect(
            ZCodeScrollSourceClassifier.shouldAcceptUserEvent(
                eventWindowID: 1,
                targetWindowID: 1,
                eventScrollViewID: 10,
                targetScrollViewID: 10
            )
        )
    }
}
