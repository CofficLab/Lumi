import Foundation
import SwiftUI
import Testing
@testable import KitMarkdown

/// tree-sitter 高亮器的行为断言。
///
/// 不变式：
/// 1. 受支持的语言必须被着色（多种颜色），而不是整块纯文本；
/// 2. 不支持/缺失的语言必须降级为 nil（调用方按纯文本渲染），不得抛错；
/// 3. 着色不得改动代码文本本身。
@MainActor
struct TreeSitterCodeHighlightProviderTests {

    private func provider(for colorScheme: ColorScheme = .light) -> TreeSitterCodeHighlightProvider {
        TreeSitterCodeHighlightProvider.make(for: colorScheme)
    }

    @Test("swift 代码被着色成多种颜色")
    func highlightsSwiftCode() throws {
        let code = """
        let greeting = "hello"
        let count = 42
        """
        let attributed = try #require(
            provider().highlight(code: code, language: "swift"),
            "swift 代码块应当被高亮"
        )

        #expect(colors(in: attributed).count >= 2, "swift 代码应当出现多种语法颜色")
    }

    @Test("各受支持语言都能被着色", arguments: [
        "swift", "javascript", "typescript", "tsx", "json", "python", "bash", "yaml",
    ])
    func highlightsSupportedLanguages(language: String) throws {
        let samples: [String: String] = [
            "swift": "let value = 1",
            "javascript": "const value = 1;",
            "typescript": "const value: number = 1;",
            "tsx": "const App = () => <div />;",
            "json": "{\"key\": \"value\"}",
            "python": "value = 1",
            "bash": "echo hello",
            "yaml": "key: value",
        ]
        let code = try #require(samples[language])
        let attributed = try #require(
            provider().highlight(code: code, language: language),
            "\(language) 代码块应当被高亮"
        )
        #expect(colors(in: attributed).count >= 1, "\(language) 代码应当被着色")
    }

    @Test("语言别名归一化到同一语法")
    func normalizesLanguageAliases() throws {
        let swift = try #require(provider().highlight(code: "let x = 1", language: "swift"))
        let upper = try #require(provider().highlight(code: "let x = 1", language: "Swift"))
        let js = try #require(provider().highlight(code: "const x = 1", language: "js"))
        let jsLong = try #require(provider().highlight(code: "const x = 1", language: "javascript"))

        #expect(colors(in: swift) == colors(in: upper), "语言标签应大小写不敏感")
        #expect(colors(in: js) == colors(in: jsLong), "js 与 javascript 应视为同一语言")
    }

    @Test("不支持的语言降级为 nil")
    func returnsNilForUnsupportedLanguage() {
        #expect(provider().highlight(code: "whatever", language: "brainfuck") == nil)
        #expect(provider().highlight(code: "whatever", language: nil) == nil)
        #expect(provider().highlight(code: "whatever", language: "  ") == nil)
    }

    @Test("高亮不改变代码文本")
    func preservesCodeText() throws {
        let code = "let greeting = \"hello\" // 注释里有中文"
        let attributed = try #require(provider().highlight(code: code, language: "swift"))
        #expect(String(attributed.characters) == code)
    }

    @Test("空代码不产生高亮")
    func returnsNilForEmptyCode() {
        #expect(provider().highlight(code: "", language: "swift") == nil)
    }

    @Test("深浅配色使用不同的 cache 标识")
    func distinguishesPalettesByCacheIdentifier() {
        #expect(
            TreeSitterCodeHighlightProvider.make(for: .light).cacheIdentifier
                != TreeSitterCodeHighlightProvider.make(for: .dark).cacheIdentifier
        )
    }

    // MARK: - 辅助

    private func colors(in attributed: AttributedString) -> Set<Color> {
        var result = Set<Color>()
        for run in attributed.runs {
            if let color = run.foregroundColor {
                result.insert(color)
            }
        }
        return result
    }
}
