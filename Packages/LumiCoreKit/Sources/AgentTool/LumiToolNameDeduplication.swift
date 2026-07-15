import Foundation

/// 工具名称去重断言工具
///
/// 确保注册的工具列表中没有重名工具。
/// 重复的工具名会导致工具调用歧义，在注册阶段应被拦截。
///
/// - Note: 提供两种调用风格：
///   - `validateUnique(tools:)` 抛出 `LumiToolRegistrationError`，供启动期与
///     业务注册流程使用，错误可被 `RootContainer` 等上游捕获并以 `CrashedView` 优雅降级。
///   - `assertUnique(tools:)` 是 `validateUnique` 的 `throws` 透传包装，
///     行为与 `validateUnique` 一致：失败时抛出 `LumiToolRegistrationError`。
///     旧实现是 `try!` + `fatalError`，现统一为抛错路径，让运行时失败也走 `CrashedView`。
public enum LumiToolNameDeduplication {
    /// 校验工具列表中的名称唯一，重复时抛出 `LumiToolRegistrationError`。
    ///
    /// 抛出的错误携带每个重复名对应的所有"主人"类型（`String(reflecting:)` 含模块路径），
    /// 调用方可直接用 `localizedDescription` 展示给用户。
    public static func validateUnique(tools: [any LumiAgentTool]) throws {
        let entries = tools.map { tool in
            ValidateEntry(name: tool.name, owner: String(reflecting: type(of: tool)))
        }
        try validateUnique(entries: entries)
    }

    /// 校验一组已经预先组装好的 `(name, owner)` 列表。
    ///
    /// 用于"尚未实例化、但名字已知"的工具源（如 `SubAgentDelegateTool` 的
    /// `delegate_<id>` 命名约定），让启动期校验不必为了凑 `LumiAgentTool` 协议
    /// 而构建空壳实例。`owner` 推荐带上来源标签（如 `"<built-in>.NoOpTool"`、
    /// `"SubAgentDelegateTool[reviewer]"`），错误信息会直接展示给用户。
    public static func validateUnique(entries: [ValidateEntry]) throws {
        var ownersByName: [String: [String]] = [:]
        for entry in entries {
            ownersByName[entry.name, default: []].append(entry.owner)
        }

        // 收集出现 >=2 次的 name
        let duplicates = ownersByName
            .filter { $0.value.count > 1 }
            .map { LumiToolDuplicateEntry(name: $0.key, owners: $0.value) }
            .sorted { $0.name < $1.name }

        if !duplicates.isEmpty {
            throw LumiToolRegistrationError.duplicateNames(duplicates)
        }
    }

    /// 单条待校验的工具名称条目。`name` 为对外暴露的工具名；`owner` 为来源标签，
    /// 错误信息中会原样展示。
    public struct ValidateEntry: Sendable, Equatable {
        public let name: String
        public let owner: String

        public init(name: String, owner: String) {
            self.name = name
            self.owner = owner
        }
    }

    /// 断言工具列表中的名称唯一，重复时抛出 `LumiToolRegistrationError`。
    ///
    /// 内部委托给 `validateUnique(tools:)`，失败时把错误向外抛出，由调用方
    /// （如 `RootContainer` / LLM 请求发送流程）统一捕获并以 `CrashedView` 优雅降级。
    ///
    /// 历史实现是 `try!` + `fatalError`，为了让运行时重复注册也能落到 `CrashedView`
    /// 而非直接闪退，这里统一改为 `throws` 透传。命名保留是为了兼容既有调用点。
    public static func assertUnique(tools: [any LumiAgentTool]) throws {
        try validateUnique(tools: tools)
    }
}