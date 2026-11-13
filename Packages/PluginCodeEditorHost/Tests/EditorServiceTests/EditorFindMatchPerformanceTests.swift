import EditorKernel
import Foundation
import Testing
@testable import EditorService

/// 查找匹配的性能修复（见 issue #1279）。
///
/// 修复包含三部分：
/// 1. 内容变化触发的匹配走防抖，连续按键只扫描一次；
/// 2. 编译好的正则按 (pattern, options) 缓存复用；
/// 3. 匹配文本改用 `NSString` 取子串，去掉「匹配数 × 文档长度」的范围换算。
///
/// 本套件断言这些改动**不改变匹配结果**。
@MainActor
struct EditorFindMatchPerformanceTests {

    private func makeState(
        findText: String = "foo",
        options: EditorFindReplaceOptions = EditorFindReplaceOptions()
    ) -> EditorFindReplaceState {
        EditorFindReplaceState(findText: findText, options: options)
    }

    @Test("普通文本匹配结果不变")
    func plainTextMatchesUnchanged() {
        let result = EditorFindReplaceController.matches(
            in: "Foo foo FOO",
            state: makeState(),
            selections: [],
            primarySelection: nil
        )

        #expect(result.matches.count == 3)
        #expect(result.matches.map(\.range) == [
            EditorRange(location: 0, length: 3),
            EditorRange(location: 4, length: 3),
            EditorRange(location: 8, length: 3),
        ])
        #expect(result.matches.map(\.matchedText) == ["Foo", "foo", "FOO"])
    }

    @Test("全词匹配结果不变")
    func wholeWordMatchesUnchanged() {
        let result = EditorFindReplaceController.matches(
            in: "cat concatenate cat",
            state: makeState(
                findText: "cat",
                options: EditorFindReplaceOptions(matchesWholeWord: true)
            ),
            selections: [],
            primarySelection: nil
        )

        #expect(result.matches.map(\.range) == [
            EditorRange(location: 0, length: 3),
            EditorRange(location: 16, length: 3),
        ])
    }

    @Test("正则匹配结果不变")
    func regexMatchesUnchanged() {
        let result = EditorFindReplaceController.matches(
            in: "a1 b2 c3",
            state: makeState(
                findText: "[a-z][0-9]",
                options: EditorFindReplaceOptions(isRegexEnabled: true)
            ),
            selections: [],
            primarySelection: nil
        )

        #expect(result.matches.count == 3)
        #expect(result.matches.map(\.matchedText) == ["a1", "b2", "c3"])
    }

    @Test("大小写敏感匹配结果不变")
    func caseSensitiveMatchesUnchanged() {
        let result = EditorFindReplaceController.matches(
            in: "Foo foo FOO",
            state: makeState(
                findText: "foo",
                options: EditorFindReplaceOptions(isCaseSensitive: true)
            ),
            selections: [],
            primarySelection: nil
        )

        #expect(result.matches.count == 1)
        #expect(result.matches.first?.range == EditorRange(location: 4, length: 3))
    }

    @Test("多字节字符的匹配文本正确")
    func multibyteMatchedTextIsCorrect() {
        let result = EditorFindReplaceController.matches(
            in: "你好世界 hello",
            state: makeState(findText: "世界"),
            selections: [],
            primarySelection: nil
        )

        #expect(result.matches.count == 1)
        #expect(result.matches.first?.matchedText == "世界")
        #expect(result.matches.first?.range == EditorRange(location: 2, length: 2))
    }

    @Test("正则缓存不影响匹配结果")
    func cachedRegularExpressionProducesSameResult() {
        let text = "foo bar foo baz foo"
        let state = makeState()

        let first = EditorFindReplaceController.matches(
            in: text,
            state: state,
            selections: [],
            primarySelection: nil
        )
        // 第二次命中缓存。
        let second = EditorFindReplaceController.matches(
            in: text,
            state: state,
            selections: [],
            primarySelection: nil
        )

        #expect(first.matches == second.matches)
        #expect(first.matches.count == 3)
    }

    @Test("不同选项各自缓存且结果正确")
    func differentOptionsCacheSeparately() {
        let text = "foo Foo FOO"

        let insensitive = EditorFindReplaceController.matches(
            in: text,
            state: makeState(),
            selections: [],
            primarySelection: nil
        )
        let sensitive = EditorFindReplaceController.matches(
            in: text,
            state: makeState(options: EditorFindReplaceOptions(isCaseSensitive: true)),
            selections: [],
            primarySelection: nil
        )

        #expect(insensitive.matches.count == 3)
        #expect(sensitive.matches.count == 1)
    }

    @Test("非法正则不崩溃且返回空结果")
    func invalidRegexYieldsNoMatches() {
        let result = EditorFindReplaceController.matches(
            in: "foo",
            state: makeState(
                findText: "[unclosed",
                options: EditorFindReplaceOptions(isRegexEnabled: true)
            ),
            selections: [],
            primarySelection: nil
        )

        #expect(result.matches.isEmpty)
    }

    @Test("防抖刷新在空闲后给出正确结果")
    func debouncedRefreshProducesCorrectResult() async throws {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        _ = state.documentController.load(text: "foo bar foo")
        state.content = state.documentController.textStorage
        state.openFindPanel()
        state.updateFindQuery("foo")

        // 内容变化触发的防抖刷新。
        state.scheduleFindMatchRefresh()
        try await Task.sleep(for: .milliseconds(400))

        #expect(state.findMatches.count == 2)
    }

    @Test("立即刷新同步给出结果")
    func immediateRefreshIsSynchronous() {
        let state = EditorState(editorExtensions: EditorExtensionRegistry())
        _ = state.documentController.load(text: "foo bar foo")
        state.content = state.documentController.textStorage
        state.openFindPanel()
        state.updateFindQuery("foo")

        state.refreshFindMatches()

        #expect(state.findMatches.count == 2)
    }
}
