import Testing
@testable import PluginLLMProviderMLX

/// `MLXModelSession` 的加载状态机回归。
///
/// #411：加载失败会丢弃容器但（修复前）保留旧模型 ID，重选原本可用的
/// 模型会被「ID 相同」跳过加载，直接撞上空容器守卫，永远无法自动恢复。
@Suite("MLX 模型会话状态")
struct MLXModelSessionTests {
    @Test("成功加载后同 ID 不重复加载，换 ID 触发加载")
    func successfulLoadSkipsReloadForSameModel() {
        var session = MLXModelSession()
        #expect(session.needsLoad(for: "A"))

        session.didFinishLoad(modelID: "A")
        #expect(!session.needsLoad(for: "A"))
        #expect(session.needsLoad(for: "B"))
    }

    @Test("加载失败丢容器后重选原模型必须重新加载（#411）")
    func discardedContainerForcesReloadOfPreviouslyLoadedModel() {
        var session = MLXModelSession()
        session.didFinishLoad(modelID: "A")

        // 切到损坏的 B：对应 generate 交换路径先丢容器（session 置空），
        // 随后加载抛错、未走到 didFinishLoad。
        session.discardContainer()

        #expect(session.needsLoad(for: "A"))
        #expect(session.needsLoad(for: "B"))

        // 重试 A 成功后回到稳定态
        session.didFinishLoad(modelID: "A")
        #expect(!session.needsLoad(for: "A"))
    }

    @Test("unload 等价于丢容器，任何模型都需要重新加载")
    func unloadClearsEverything() {
        var session = MLXModelSession()
        session.didFinishLoad(modelID: "A")
        session.discardContainer()

        #expect(session.needsLoad(for: "A"))
        #expect(session.needsLoad(for: "B"))
    }
}
