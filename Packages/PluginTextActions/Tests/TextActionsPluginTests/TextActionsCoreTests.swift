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

// MARK: - 菜单布局

@Suite("Text Actions 菜单布局")
struct TextActionMenuLayoutTests {

    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let size = CGSize(width: 200, height: 120)

    @Test("锚点居中时水平居中、垂直下移")
    func centersOnAnchor() {
        let frame = TextActionMenuLayout.frame(
            for: CGPoint(x: 700, y: 400),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.width == 200)
        #expect(frame.height == 120)
        #expect(frame.midX == 700)
        #expect(frame.minY == 418)
    }

    @Test("靠左时夹到屏幕左边")
    func clampsToLeftEdge() {
        let frame = TextActionMenuLayout.frame(
            for: CGPoint(x: 10, y: 400),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.minX == screen.minX)
    }

    @Test("靠右时夹到屏幕右边")
    func clampsToRightEdge() {
        let frame = TextActionMenuLayout.frame(
            for: CGPoint(x: 1439, y: 400),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.maxX == screen.maxX - 8)
    }

    @Test("靠上时夹到屏幕上边")
    func clampsToTopEdge() {
        let frame = TextActionMenuLayout.frame(
            for: CGPoint(x: 700, y: 899),
            menuSize: size,
            screenFrame: screen
        )

        #expect(frame.maxY == screen.maxY - 8)
    }

    @Test("自定义边距与偏移生效")
    func respectsCustomMarginAndOffset() {
        let frame = TextActionMenuLayout.frame(
            for: CGPoint(x: 700, y: 400),
            menuSize: size,
            screenFrame: screen,
            margin: 20,
            verticalOffset: 50
        )

        #expect(frame.minY == 450)
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
    }
}
