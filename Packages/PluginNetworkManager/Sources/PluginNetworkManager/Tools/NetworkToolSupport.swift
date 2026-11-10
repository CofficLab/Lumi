import KitAgentTool
import Foundation

/// Network Manager Agent 工具的共享支持逻辑（KernelCore 体系）。
///
/// 由旧版 `Plugins/NetworkManagerPlugin/Sources/Tools/*` 迁移而来，差异：
/// - 参数类型 `[String: LumiJSONValue]` → `[String: ToolArgument]`；
/// - 不再依赖 `KernelLumi`。
enum NetworkToolSupport {
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        arguments[key]?.value as? String
    }

    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        ToolArgumentNumber.int(arguments[key]?.value)
    }

    /// 读取分页上限：负数/非法值回退默认值，再钳制到上限。
    ///
    /// 调用方会把结果直接交给 `prefix(_:)`，负数会触发集合切片陷阱。
    static func limit(
        _ arguments: [String: ToolArgument],
        _ key: String = "limit",
        default defaultValue: Int,
        max maximum: Int
    ) -> Int {
        guard let requested = int(arguments, key), requested > 0 else { return defaultValue }
        return min(requested, maximum)
    }

    static func bool(_ arguments: [String: ToolArgument], _ key: String) -> Bool? {
        guard let value = arguments[key]?.value else { return nil }
        if let bool = value as? Bool { return bool }
        if let string = value as? String {
            switch string.lowercased() {
            case "true", "yes", "1": return true
            case "false", "no", "0": return false
            default: return nil
            }
        }
        return nil
    }

    static func double(_ arguments: [String: ToolArgument], _ key: String) -> Double? {
        guard let value = arguments[key]?.value else { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return Double(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        if let string = value as? String { return Double(string) }
        return nil
    }

    static func stringArray(_ arguments: [String: ToolArgument], _ key: String) -> [String]? {
        guard let array = arguments[key]?.value as? [Any] else { return nil }
        return array.compactMap { $0 as? String }
    }
}
