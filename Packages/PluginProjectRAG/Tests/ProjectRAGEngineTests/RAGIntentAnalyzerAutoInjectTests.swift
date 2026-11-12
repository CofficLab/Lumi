import Foundation
import ProjectRAGEngine
import Testing

@Suite("RAGIntentAnalyzerAutoInject")
struct RAGIntentAnalyzerAutoInjectTests {
    @Test("casual question does not auto inject")
    func casualQuestionDoesNotAutoInject() {
        #expect(RAGIntentAnalyzer.shouldAutoInject(for: "今天天气怎么样") == false)
    }

    @Test("design question auto injects")
    func designQuestionAutoInjects() {
        #expect(RAGIntentAnalyzer.shouldAutoInject(for: "登录功能是怎么设计的") == true)
    }

    @Test("identifier question auto injects")
    func identifierQuestionAutoInjects() {
        #expect(RAGIntentAnalyzer.shouldAutoInject(for: "LoginViewController 在哪初始化") == true)
    }

    @Test("broad trigger still allows tool use but not auto injection")
    func broadTriggerStillAllowsToolUse() {
        #expect(RAGIntentAnalyzer.shouldUseRAG(for: "这个项目怎么样") == true)
        #expect(RAGIntentAnalyzer.shouldAutoInject(for: "这个项目怎么样") == false)
    }
}