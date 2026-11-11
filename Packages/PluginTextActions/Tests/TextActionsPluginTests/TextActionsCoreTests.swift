import AppKit
import Foundation
import Testing
@testable import TextActionsPlugin

// MARK: - 选区读取策略

@Suite("Text Actions 选区策略")
struct TextSelectionReadPolicyTests {

    @Test("空白与空选区不弹菜单")
    func doesNotPresentMenuForBlankText() {
        #expect(TextSelectionReadPolicy.shouldPresentMenu(for: nil) == false)
        #expect(TextSelectionReadPolicy.shouldPresentMenu(for: "") == false)
        #expect(TextSelectionReadPolicy.shouldPresentMenu(for: "   ") == false)
        #expect(TextSelectionReadPolicy.shouldPresentMenu(for: "\n\t ") == false)
    }

    @Test("有内容的选区弹菜单")
    func presentsMenuForRealText() {
        #expect(TextSelectionReadPolicy.shouldPresentMenu(for: "hello"))
        #expect(TextSelectionReadPolicy.shouldPresentMenu(for: " hello "))
    }

    @Test("重试节奏常量固定")
    func retryConstants() {
        #expect(TextSelectionReadPolicy.initialDelay == .milliseconds(60))
        #expect(TextSelectionReadPolicy.retryDelay == .milliseconds(100))
        #expect(TextSelectionReadPolicy.retryCount == 3)
    }
}

// MARK: - 选择手势判定

@Suite("Text Actions 选择手势判定")
struct TextSelectionGesturePolicyTests {

    @Test("拖拽超过阈值算选择")
    func dragBeyondThresholdIsSelection() {
        #expect(TextSelectionGesturePolicy.isSelectionGesture(
            pressLocation: CGPoint(x: 100, y: 100),
            releaseLocation: CGPoint(x: 240, y: 112),
            clickCount: 1,
            modifiers: []
        ))
    }

    @Test("阈值内的抖动单击不算选择")
    func clickWithJitterIsNotSelection() {
        // 回归「点复制按钮也弹菜单」：单击（含手部抖动）不是选择手势，
        // 即使应用里仍有选区也不得触发读取。
        #expect(!TextSelectionGesturePolicy.isSelectionGesture(
            pressLocation: CGPoint(x: 100, y: 100),
            releaseLocation: CGPoint(x: 100, y: 100),
            clickCount: 1,
            modifiers: []
        ))
        #expect(!TextSelectionGesturePolicy.isSelectionGesture(
            pressLocation: CGPoint(x: 100, y: 100),
            releaseLocation: CGPoint(x: 102, y: 101),
            clickCount: 1,
            modifiers: []
        ))
    }

    @Test("双击/三击无位移也算选择")
    func multiClickIsSelection() {
        for clickCount in [2, 3] {
            #expect(TextSelectionGesturePolicy.isSelectionGesture(
                pressLocation: CGPoint(x: 50, y: 50),
                releaseLocation: CGPoint(x: 50, y: 50),
                clickCount: clickCount,
                modifiers: []
            ))
        }
    }

    @Test("Shift+单击扩选算选择")
    func shiftClickIsSelection() {
        #expect(TextSelectionGesturePolicy.isSelectionGesture(
            pressLocation: CGPoint(x: 50, y: 50),
            releaseLocation: CGPoint(x: 50, y: 50),
            clickCount: 1,
            modifiers: [.shift]
        ))
    }

    @Test("没有按下位置时单击不算选择")
    func missingPressLocationIsNotSelection() {
        // 监听刚启用、没捕获到 mouseDown：无法判定拖拽，保守不触发。
        #expect(!TextSelectionGesturePolicy.isSelectionGesture(
            pressLocation: nil,
            releaseLocation: CGPoint(x: 200, y: 200),
            clickCount: 1,
            modifiers: []
        ))
        // 但双击与 Shift+单击不依赖按下位置。
        #expect(TextSelectionGesturePolicy.isSelectionGesture(
            pressLocation: nil,
            releaseLocation: CGPoint(x: 200, y: 200),
            clickCount: 2,
            modifiers: []
        ))
    }

    @Test("拖拽阈值常量固定")
    func dragThresholdIsStable() {
        #expect(TextSelectionGesturePolicy.dragThreshold == 4)
    }
}

// MARK: - 坐标换算

@Suite("Text Actions 坐标换算")
struct TextActionCoordinatesTests {

    @Test("Quartz 左上原点翻转为 Cocoa 左下原点")
    func flipsVerticalOrigin() {
        let quartz = CGRect(x: 100, y: 50, width: 200, height: 20)
        let cocoa = TextActionCoordinates.quartzToCocoa(quartz, primaryScreenHeight: 900)

        #expect(cocoa.minX == 100)
        #expect(cocoa.width == 200)
        #expect(cocoa.height == 20)
        // Cocoa y = 900 - 50 - 20
        #expect(cocoa.minY == 830)
        #expect(cocoa.maxY == 850)
    }

    @Test("多屏下主屏左侧的负坐标保持不变")
    func keepsNegativeCoordinates() {
        let quartz = CGRect(x: -800, y: 100, width: 300, height: 20)
        let cocoa = TextActionCoordinates.quartzToCocoa(quartz, primaryScreenHeight: 900)

        #expect(cocoa.minX == -800)
        #expect(cocoa.minY == 780)
    }
}

// MARK: - 菜单布局

@Suite("Text Actions 菜单布局")
struct TextActionMenuLayoutTests {

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 200, height: 44)

    @Test("菜单显示在选区上方居中")
    func placesAboveSelectionCentered() {
        let selection = CGRect(x: 640, y: 400, width: 120, height: 20)
        let frame = TextActionMenuLayout.frame(
            selectionRect: selection,
            anchor: CGPoint(x: 0, y: 0),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.width == 200)
        #expect(frame.height == 44)
        #expect(frame.midX == selection.midX)
        #expect(frame.minY == selection.maxY + 6)
    }

    @Test("上方空间不足时放到选区下方")
    func fallsBelowWhenNoRoomAbove() {
        // 选区贴近屏幕顶部，上方放不下 44pt 的菜单。
        let selection = CGRect(x: 640, y: 870, width: 120, height: 20)
        let frame = TextActionMenuLayout.frame(
            selectionRect: selection,
            anchor: CGPoint(x: 0, y: 0),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.maxY == selection.minY - 6)
    }

    @Test("选区靠左时夹到屏幕左边距")
    func clampsToLeftEdge() {
        let selection = CGRect(x: 0, y: 400, width: 60, height: 20)
        let frame = TextActionMenuLayout.frame(
            selectionRect: selection,
            anchor: CGPoint(x: 0, y: 0),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.minX == screen.minX + 8)
    }

    @Test("选区靠右时夹到屏幕右边距")
    func clampsToRightEdge() {
        let selection = CGRect(x: 1380, y: 400, width: 60, height: 20)
        let frame = TextActionMenuLayout.frame(
            selectionRect: selection,
            anchor: CGPoint(x: 0, y: 0),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.maxX == screen.maxX - 8)
    }

    @Test("无选区 bounds 时回退到锚点上方")
    func fallsBackToAnchor() {
        let anchor = CGPoint(x: 700, y: 400)
        let frame = TextActionMenuLayout.frame(
            selectionRect: nil,
            anchor: anchor,
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.midX == anchor.x)
        #expect(frame.minY == anchor.y + 14)
    }

    @Test("上下都放不下时夹回屏幕内")
    func clampsVerticallyWhenNeitherSideFits() {
        // 超高菜单：上下都放不下。
        let hugeSize = CGSize(width: 200, height: 800)
        let selection = CGRect(x: 640, y: 800, width: 120, height: 20)
        let frame = TextActionMenuLayout.frame(
            selectionRect: selection,
            anchor: CGPoint(x: 0, y: 0),
            menuSize: hugeSize,
            screenFrame: screen
        )

        #expect(frame.minY >= screen.minY)
        #expect(frame.maxY <= screen.maxY)
    }

    @Test("自定义边距与间距生效")
    func respectsCustomMarginAndGap() {
        let selection = CGRect(x: 640, y: 400, width: 120, height: 20)
        let frame = TextActionMenuLayout.frame(
            selectionRect: selection,
            anchor: CGPoint(x: 0, y: 0),
            menuSize: size,
            screenFrame: screen,
            margin: 20,
            gap: 12
        )

        #expect(frame.minY == selection.maxY + 12)
    }
}

// MARK: - 多屏选屏

@Suite("Text Actions 多屏选屏")
struct TextActionScreenSelectionTests {
    private let mainScreen = CGRect(x: 0, y: 0, width: 1_440, height: 900)
    private let secondaryScreen = CGRect(x: -1_920, y: 0, width: 1_920, height: 1_080)
    private let mouseAnchor = CGPoint(x: 200, y: 200)

    @Test("有选区 bounds 时按选区所在屏幕布局")
    func selectionRectWinsOverMouseAnchor() {
        // 鼠标停在主屏，选区在副屏——键盘操作时的典型场景。
        let selection = CGRect(x: -1_000, y: 500, width: 120, height: 20)
        let index = TextActionScreenSelection.screenIndex(
            selectionRect: selection,
            anchor: mouseAnchor,
            screenFrames: [mainScreen, secondaryScreen]
        )

        #expect(index == 1)
    }

    @Test("无选区 bounds 时回退到鼠标锚点所在屏幕")
    func fallsBackToAnchorWithoutSelectionRect() {
        let index = TextActionScreenSelection.screenIndex(
            selectionRect: nil,
            anchor: CGPoint(x: -500, y: 400),
            screenFrames: [mainScreen, secondaryScreen]
        )

        #expect(index == 1)
    }

    @Test("空选区 bounds 等同不可用")
    func emptySelectionRectFallsBackToAnchor() {
        let index = TextActionScreenSelection.screenIndex(
            selectionRect: CGRect(x: -1_000, y: 500, width: 0, height: 0),
            anchor: mouseAnchor,
            screenFrames: [mainScreen, secondaryScreen]
        )

        #expect(index == 0)
    }

    @Test("选区中心落在屏幕外时回退到锚点")
    func offscreenSelectionFallsBackToAnchor() {
        let selection = CGRect(x: 5_000, y: 5_000, width: 100, height: 20)
        let index = TextActionScreenSelection.screenIndex(
            selectionRect: selection,
            anchor: mouseAnchor,
            screenFrames: [mainScreen, secondaryScreen]
        )

        #expect(index == 0)
    }

    @Test("没有屏幕时返回 nil")
    func noScreensReturnsNil() {
        let index = TextActionScreenSelection.screenIndex(
            selectionRect: CGRect(x: 0, y: 0, width: 10, height: 10),
            anchor: CGPoint(x: 5, y: 5),
            screenFrames: []
        )

        #expect(index == nil)
    }
}

// MARK: - 消失策略

@Suite("Text Actions 消失策略")
struct TextActionDismissPolicyTests {

    @Test("普通按键与快捷键让菜单消失")
    func keyDownDismisses() {
        #expect(TextActionDismissPolicy.shouldDismissOnKeyDown(modifiers: []) == true)
        #expect(TextActionDismissPolicy.shouldDismissOnKeyDown(modifiers: [.command]) == true)
        #expect(TextActionDismissPolicy.shouldDismissOnKeyDown(modifiers: [.command, .shift]) == true)
        #expect(TextActionDismissPolicy.shouldDismissOnKeyDown(modifiers: [.control]) == true)
    }

    @Test("仅 Shift 的组合不消失——正在调整选区")
    func shiftOnlyDoesNotDismiss() {
        #expect(TextActionDismissPolicy.shouldDismissOnKeyDown(modifiers: [.shift]) == false)
    }

    @Test("菜单不可见时只有选择键的 keyUp 触发重读")
    func keyUpEvaluationGating() {
        // 普通打字与非选择快捷键不读 AX。
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [], menuVisible: false, keyCode: 0) == false)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command], menuVisible: false, keyCode: 1) == false)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.shift], menuVisible: false, keyCode: 13) == false)
        // Shift+方向键 / Home / End 扩选、Cmd+A 全选是选择动作。
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.shift], menuVisible: false, keyCode: 123) == true)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command, .shift], menuVisible: false, keyCode: 124) == true)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.shift], menuVisible: false, keyCode: 115) == true)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command], menuVisible: false, keyCode: 0) == true)
        // 菜单可见时保留重读，Shift 调整选区后更新位置。
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [], menuVisible: true, keyCode: 0) == true)
    }

    @Test("复制/剪切快捷键的 keyUp 永不触发重读")
    func copyAndCutShortcutsNeverEvaluate() {
        // 回归「复制后弹菜单」：菜单不在时按 Cmd+C，keyUp 不得重读选区，
        // 否则读到的旧选区会把菜单弹出来。菜单可见时同样排除，
        // 不依赖「keyDown 先收起菜单」的时序。
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command], menuVisible: false, keyCode: 8) == false)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command], menuVisible: true, keyCode: 8) == false)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command], menuVisible: false, keyCode: 7) == false)
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [.command], menuVisible: true, keyCode: 7) == false)
        // 不带 Command 的 C/X 是普通打字，同样不读。
        #expect(TextActionDismissPolicy.shouldEvaluateOnKeyUp(modifiers: [], menuVisible: false, keyCode: 8) == false)
    }

    @Test("滚动阈值固定")
    func scrollThresholdIsStable() {
        #expect(TextActionDismissPolicy.scrollThreshold == 60)
    }

    @Test("落在浮层窗口内的事件不算外部事件")
    func eventInsidePanelIsIgnored() {
        #expect(TextActionDismissPolicy.isInsidePanel(eventWindowNumber: 42, panelWindowNumber: 42))
    }

    @Test("落在其他窗口的事件会关闭浮层")
    func eventInOtherWindowIsDismissed() {
        #expect(!TextActionDismissPolicy.isInsidePanel(eventWindowNumber: 7, panelWindowNumber: 42))
    }

    @Test("窗口号未知时不能误判为浮层内")
    func unknownWindowNumberNeverMatches() {
        #expect(!TextActionDismissPolicy.isInsidePanel(eventWindowNumber: 0, panelWindowNumber: 0))
        #expect(!TextActionDismissPolicy.isInsidePanel(eventWindowNumber: 0, panelWindowNumber: 42))
    }
}

// MARK: - 动作目录

@Suite("Text Actions 动作目录")
struct TextActionCatalogTests {

    @Test("三个动作可枚举且标识稳定")
    func actionsAreCaseIterable() {
        #expect(TextAction.allCases.count == 3)
        #expect(TextAction.copy.id == .copy)
        #expect(TextAction.search.id == .search)
        #expect(TextAction.translate.id == .translate)
    }

    @Test("每个动作有标题与图标")
    func actionsHaveTitlesAndIcons() {
        #expect(TextAction.copy.title.isEmpty == false)
        #expect(TextAction.search.title.isEmpty == false)
        #expect(TextAction.translate.title.isEmpty == false)
        #expect(TextAction.copy.systemImage == "doc.on.doc")
        #expect(TextAction.search.systemImage == "magnifyingglass")
        #expect(TextAction.translate.systemImage == "character.book.closed")
    }

    @Test("搜索地址用百分号编码查询词")
    func buildsSearchURL() throws {
        let url = try #require(TextAction.searchURL(for: "a b&c=d 中文"))

        #expect(url.absoluteString.hasPrefix("https://www.google.com/search?"))
        #expect(url.absoluteString.contains("q="))
        #expect(url.absoluteString.contains("%26"))
        #expect(url.absoluteString.contains("%3D"))
    }

    @Test("翻译请求带固定的 system 指令与原文 user 消息")
    func buildsTranslationRequest() {
        let request = TextAction.v2TranslationRequest(for: "hello")

        #expect(request.messages.count == 2)
        #expect(request.messages[0].role == .system)
        #expect(request.messages[0].content.contains("Simplified Chinese"))
        #expect(request.messages[1].role == .user)
        #expect(request.messages[1].content == "hello")
    }

    @Test("旧版翻译请求与新版语义一致")
    func legacyTranslationRequestMatchesV2() {
        let legacy = TextAction.translationRequest(for: "hello")
        let v2 = TextAction.v2TranslationRequest(for: "hello")

        #expect(legacy.messages.count == v2.messages.count)
        #expect(legacy.messages.map(\.role) == v2.messages.map(\.role))
        #expect(legacy.messages.map(\.content) == v2.messages.map(\.content))
    }
}

// MARK: - 选区结果

@Suite("Text Actions 选区结果")
struct SelectedTextTests {

    @Test("选区结果按值比较")
    func selectedTextIsEquatable() {
        let anchor = CGPoint(x: 10, y: 20)
        let first = SelectedText(text: "hello", anchor: anchor)
        let second = SelectedText(text: "hello", anchor: anchor)
        let other = SelectedText(text: "world", anchor: anchor)

        #expect(first == second)
        #expect(first != other)
        #expect(first.anchor == anchor)
        #expect(first.selectionRect == nil)
    }

    @Test("携带选区 bounds 参与比较")
    func carriesSelectionRect() {
        let rect = CGRect(x: 1, y: 2, width: 3, height: 4)
        let withRect = SelectedText(text: "hello", anchor: .zero, selectionRect: rect)

        #expect(withRect.selectionRect == rect)
        #expect(withRect != SelectedText(text: "hello", anchor: .zero))
    }
}
