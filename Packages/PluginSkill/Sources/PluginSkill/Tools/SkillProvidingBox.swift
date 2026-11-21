import Foundation
import ProviderSkill

/// 把 `SkillProviding`（`@MainActor`、非 `Sendable`）装进可跨并发域传递的盒子。
///
/// Agent 工具是 `Sendable` 结构体，不能直接持有 Provider 引用；盒子把
/// 访问全部收敛到 `MainActor`，工具在任意执行器上都能安全取底座技能。
final class SkillProvidingBox: @unchecked Sendable {
    private let provider: (any SkillProviding)?

    init(_ provider: (any SkillProviding)?) {
        self.provider = provider
    }

    /// 是否真的注入了 Provider；nil 包裹时调用方应回退内置目录。
    var hasProvider: Bool { provider != nil }

    func allSkills() async -> [SkillMetadata] {
        guard let provider else { return [] }
        return await MainActor.run { provider.allSkills() }
    }

    func skill(named name: String) async -> SkillMetadata? {
        guard let provider else { return nil }
        return await MainActor.run {
            provider.allSkills().first { $0.name == name }
        }
    }
}
