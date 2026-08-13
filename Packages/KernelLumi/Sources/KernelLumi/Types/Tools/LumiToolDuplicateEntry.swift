import Foundation

/// 单个被重复注册的工具条目,作为 ``LumiToolRegistrationError/duplicateNames``
/// 的关联值使用。
///
/// 同时被 `LLMKit/LumiToolNameDeduplication` 直接构造,因此保留在
/// `Types/Tools/` 而非 `Errors/`,避免对调用方不必要的路径耦合。
public struct LumiToolDuplicateEntry: Sendable, Equatable {
    public let name: String
    public let owners: [String]
    public init(name: String, owners: [String]) {
        self.name = name
        self.owners = owners
    }
}
