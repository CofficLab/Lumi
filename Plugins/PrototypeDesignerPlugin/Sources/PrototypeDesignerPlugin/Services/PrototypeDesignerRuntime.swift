import Foundation
import KernelLumi

/// 原型设计器运行时单例。
///
/// 缓存「当前原型产物」，让 `generate_prototype` 与 `refine_prototype` 两个工具
/// 共享同一份状态（refine 基于 generate 的结果增量修改）。
/// 由插件 `onBoot` 调用 `reset()` 完成初始化。
@MainActor
final class PrototypeDesignerRuntime {
    static let shared = PrototypeDesignerRuntime()

    /// 当前原型产物（最近一次 generate/refine 的结果）。
    private(set) var currentArtifact: PrototypeArtifact?

    /// 工具内部一次性调用 LLM 用的占位会话 ID。
    ///
    /// 工具走 `kernel.llmProvider.generateText`（不写消息库、不触发 agent turn），
    /// 此 ID 仅为满足 `LumiChatMessage.conversationID` 类型要求，不参与持久化。
    let scratchConversationID = UUID()

    private init() {}

    /// 更新当前原型产物（由工具在生成/修改成功后调用）。
    func updateArtifact(_ artifact: PrototypeArtifact) {
        currentArtifact = artifact
    }

    /// 清空当前原型产物。
    func reset() {
        currentArtifact = nil
    }
}
