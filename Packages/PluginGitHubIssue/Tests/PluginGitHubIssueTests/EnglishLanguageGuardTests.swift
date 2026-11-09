import Foundation
import Testing
@testable import PluginGitHubIssue

/// 英文校验守卫的单元测试。
///
/// 这些是纯函数，不依赖 gh / 网络，可稳定断言。
@Suite("EnglishLanguageGuard")
struct EnglishLanguageGuardTests {

    @Test("plain English passes")
    func plainEnglishPasses() {
        #expect(!EnglishLanguageGuard.containsNonEnglishContent(
            "The tool returned an empty result when the file path contained spaces."
        ))
    }

    @Test("Chinese content is rejected")
    func chineseRejected() {
        #expect(EnglishLanguageGuard.containsNonEnglishContent(
            "工具在处理空格路径时返回了空结果"
        ))
    }

    @Test("Japanese content is rejected")
    func japaneseRejected() {
        #expect(EnglishLanguageGuard.containsNonEnglishContent(
            "ツールがパスの空白を含む場合、空の結果を返しました"
        ))
    }

    @Test("Korean content is rejected")
    func koreanRejected() {
        #expect(EnglishLanguageGuard.containsNonEnglishContent(
            "경로에 공백이 포함되면 빈 결과가 반환됩니다"
        ))
    }

    @Test("a single CJK character is tolerated")
    func singleCJKCharacterTolerated() {
        // 单个字符可能来自误输入或表情，不足以判定为非英文。
        #expect(!EnglishLanguageGuard.containsNonEnglishContent("Crash on launch 中"))
    }

    @Test("CJK punctuation alone is tolerated")
    func cjkPunctuationTolerated() {
        #expect(!EnglishLanguageGuard.containsNonEnglishContent("Error: 「not found」"))
    }

    @Test("short but fully Chinese text is rejected by ratio")
    func shortPureCJKRejectedByRatio() {
        #expect(EnglishLanguageGuard.containsNonEnglishContent("崩溃"))
        #expect(EnglishLanguageGuard.containsNonEnglishContent("闪退"))
        #expect(EnglishLanguageGuard.containsNonEnglishContent("中"))
    }

    @Test("short English text with a single CJK character is still tolerated")
    func shortEnglishWithSingleCJKPasses() {
        #expect(!EnglishLanguageGuard.containsNonEnglishContent("Fix: 中"))
        #expect(!EnglishLanguageGuard.containsNonEnglishContent("Crash on launch 中"))
    }

    @Test("splitting Chinese across title and body is still rejected (#1050)")
    func splitChineseAcrossFieldsRejected() {
        let offenders = CreateGitHubIssueTool.nonEnglishOffendersForTesting(title: "崩溃", body: "闪退")
        #expect(offenders.contains { $0.contains("title") })
        #expect(offenders.contains { $0.contains("body") })

        // 每个字段各只有 1 个 CJK 字符，绝对阈值达不到，仍须拒绝。
        let singleCharacterFields = CreateGitHubIssueTool.nonEnglishOffendersForTesting(title: "崩", body: "溃")
        #expect(!singleCharacterFields.isEmpty)
    }

    @Test("counting is accurate")
    func countingIsAccurate() {
        #expect(EnglishLanguageGuard.nonLatinCharacterCount(in: "abc") == 0)
        #expect(EnglishLanguageGuard.nonLatinCharacterCount(in: "中文") == 2)
        #expect(EnglishLanguageGuard.nonLatinCharacterCount(in: "a中b文c") == 2)
    }

    @Test("English code snippets do not trigger rejection")
    func englishCodeSnippetsPass() {
        let code = """
        func main() {
            let x = [1, 2, 3].map { $0 * 2 }
            print("Result: \\(x)")
        }
        """
        #expect(!EnglishLanguageGuard.containsNonEnglishContent(code))
    }
}
