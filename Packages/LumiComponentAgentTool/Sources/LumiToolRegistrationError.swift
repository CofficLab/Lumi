import Foundation

/// 工具注册阶段的错误类型
///
/// 由 `LumiToolNameDeduplication.validateUnique(tools:)` 抛出，捕获后通常以
/// `CrashedView` 等优雅降级 UI 呈现给用户，避免 `fatalError` 直接闪退。
///
/// 设计上放在 `LumiCoreKit`（内核最底层），与 `LumiLLMProviderSupportError` 同层；
/// UI 层只需依赖本错误类型的 `LocalizedError` 描述，无需感知具体校验逻辑。
public enum LumiToolRegistrationError: LocalizedError {
    /// 注册的工具列表中出现重复名称
    ///
    /// - Parameter entries: 每个重复名对应的冲突条目（包含工具名与所有"主人"类型）。
    ///   按工具名字典序排序，便于稳定展示与测试断言。
    case duplicateNames([LumiToolDuplicateEntry])
}

/// 单个工具名称冲突的条目
///
/// 携带冲突的工具名与所有声明该名字的工具类型名（按出现顺序，第一个为首个注册者）。
/// 类型名通过 `String(reflecting:)` 生成，包含模块路径（如 `LumiCoreKit.ConversationInfoTool`），
/// 足以唯一定位重复源头。
public struct LumiToolDuplicateEntry: Sendable, Equatable {
    public let name: String
    public let owners: [String]

    public init(name: String, owners: [String]) {
        self.name = name
        self.owners = owners
    }
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
        switch self {
        case .duplicateNames:
            return "多个工具声明了相同的 name，这会导致工具调用歧义。请禁用冲突的插件或重命名其中之一。"
        }
    }
}