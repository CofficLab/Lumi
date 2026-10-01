import Foundation
import KitLLM

/// GoatPlan 远程模型列表的静态合并工具。
///
/// 将「静态基线」与「远程拉取到的模型」按 id 合并：
/// - 远程优先：同 id 模型用远程的 displayName / contextWindowSize 覆盖基线
/// - 静态补齐：远程未覆盖的基线模型原样保留，保证永不为空
/// - 排序：先按基线声明顺序，远程新增模型追加在后
enum RemoteModelMerger {

    /// 合并静态基线与远程模型。
    ///
    /// - Parameters:
    ///   - base: 硬编码的静态基线（通常来自 `providerInfo.models`）。
    ///   - remote: 远程拉取到的模型快照（可为空，此时等价于返回 base）。
    /// - Returns: 合并后的模型列表，**永不为空**（base 非空时）。
    static func merge(base: [LLMModelInfo], remote: [LLMModelInfo]) -> [LLMModelInfo] {
        guard !remote.isEmpty else { return base }

        // 远程优先覆盖同 id 元数据
        var byID: [String: LLMModelInfo] = [:]
        for model in base { byID[model.id] = model }
        for model in remote { byID[model.id] = model }

        // 按基线顺序输出，远程新增追加在后
        var seen = Set<String>()
        var merged: [LLMModelInfo] = []
        for model in base {
            merged.append(byID[model.id] ?? model)
            seen.insert(model.id)
        }
        for model in remote where !seen.contains(model.id) {
            merged.append(model)
            seen.insert(model.id)
        }
        return merged
    }
}
