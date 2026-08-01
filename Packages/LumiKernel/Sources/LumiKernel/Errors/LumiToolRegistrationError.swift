import Foundation

/// 工具注册阶段抛出的错误。
///
/// 关联值类型 ``LumiToolDuplicateEntry`` 保留在
/// `Types/Tools/LumiToolRegistrationError.swift` 中,因其同时被
/// `LLMKit/LumiToolNameDeduplication` 作为去重结果直接构造,跨包共享更方便。
public enum LumiToolRegistrationError: LocalizedError {
    case duplicateNames([LumiToolDuplicateEntry])
}

extension LumiToolRegistrationError {
    public var errorDescription: String? {
        switch self {
        case .duplicateNames(let entries):
            let lines = entries.map { entry in
                "  • \(entry.name): \(entry.owners.joined(separator: ", "))"
            }
            return "工具名称冲突 (\(entries.count) 个):\n\(lines.joined(separator: "\n"))"
        }
    }
    public var failureReason: String? {
        "多个工具声明了相同的 name，这会导致工具调用歧义。请禁用冲突的插件或重命名其中之一。"
    }
}
