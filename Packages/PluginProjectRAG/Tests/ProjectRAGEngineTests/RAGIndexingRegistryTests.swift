import Foundation
import Testing

@testable import ProjectRAGEngine

/// 回归 #1110：同一项目的索引作用域可以重叠，任一作用域先结束都不能清掉
/// 其他仍在运行的索引标记。
@Suite struct RAGIndexingRegistryTests {
    @Test("重叠索引作用域在最后一个结束前保持索引状态")
    func overlappingScopesStayIndexingUntilLastFinish() {
        let registry = RAGIndexingRegistry()
        let project = "/tmp/lumi-rag-overlap"

        registry.start(projectPath: project)
        registry.start(projectPath: project)
        registry.finish(projectPath: project)

        #expect(registry.contains(projectPath: project))
        #expect(registry.hasAnyIndexing())

        registry.finish(projectPath: project)

        #expect(!registry.contains(projectPath: project))
        #expect(!registry.hasAnyIndexing())
    }

    @Test("不同项目的索引状态互不影响")
    func projectScopesAreIndependent() {
        let registry = RAGIndexingRegistry()
        let first = "/tmp/lumi-rag-first"
        let second = "/tmp/lumi-rag-second"

        registry.start(projectPath: first)
        registry.start(projectPath: second)
        registry.finish(projectPath: first)

        #expect(!registry.contains(projectPath: first))
        #expect(registry.contains(projectPath: second))
        #expect(registry.hasAnyIndexing())

        registry.finish(projectPath: second)

        #expect(!registry.hasAnyIndexing())
    }

    @Test("多余的 finish 不会留下负计数")
    func unmatchedFinishDoesNotUnderflow() {
        let registry = RAGIndexingRegistry()
        let project = "/tmp/lumi-rag-unmatched"

        registry.finish(projectPath: project)

        #expect(!registry.contains(projectPath: project))
        #expect(!registry.hasAnyIndexing())

        registry.start(projectPath: project)
        #expect(registry.contains(projectPath: project))

        registry.finish(projectPath: project)
        #expect(!registry.hasAnyIndexing())
    }
}
