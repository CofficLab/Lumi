import Foundation

/// 把 Foundation 的 JSON 值转换成可跨并发边界传递的 `Sendable` 值。
///
/// ## 为什么需要它
///
/// MLX 的 chat template 需要 `Sendable` 的工具 Schema（`ToolSpec` 是
/// `[String: any Sendable]`），而 JSON 解析出来的值里混着 `NSNull`
/// （JSON `null`）、`NSNumber` 等非 `Sendable` 类型。
///
/// 转换必须**保持 JSON 语义**：
/// - JSON `null` 必须继续是空值，不能变成字符串 `"<null>"`；
/// - `enum` / `const` / `default` / `examples` 里的空值一旦变成字符串，
///   模型看到的就是另一个 Schema，生成的参数会被 MCP 服务端的 Schema 校验
///   拒绝。
///
/// ## 空值的表示
///
/// `ToolSpec` 的值类型是 `any Sendable`，无法直接承载 `nil`。这里用
/// `Optional<Any>.none`（即「包着 nil 的 Optional」）表达 JSON 空值：
/// 下游的 Jinja 模板引擎会把这种形态降级为 JSON `null`，而不是报错或
/// 变成字符串。
enum MLXSendableJSON {

    /// 表达 JSON 空值的 `Sendable` 载荷。
    ///
    /// 空值用「包着 nil 的 Optional」表达：`ToolSpec` 的值类型是
    /// `any Sendable`，无法直接承载 `nil`；而下游 Jinja 模板引擎的
    /// `Value(any:)` 正是把这种形态还原成 JSON `null`（而不是报错或
    /// 变成字符串）。
    struct NullPayload: @unchecked Sendable {
        /// `Optional<Any>.none`：非 nil 的 Optional 包着 nil。
        let erased: Any

        init() {
            erased = Optional<Any>.none as Any
        }
    }

    /// JSON 空值的载荷。
    static let nullValue: any Sendable = NullPayload()

    /// 判断某个值是否代表 JSON 空值。
    static func isNull(_ value: Any?) -> Bool {
        guard let value else { return true }
        if value is NullPayload { return true }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return false }
        return mirror.children.isEmpty
    }

    /// 递归转换单个 JSON 值。
    ///
    /// - Returns: 可跨并发边界传递的值；JSON 空值返回 ``nullValue``。
    static func convert(_ value: Any?) -> any Sendable {
        switch value {
        case nil:
            return nullValue
        case let value as NSNull:
            // JSON `null`：保持为空值，而不是它的调试描述字符串。
            return nullValue
        case let value as String:
            return value
        case let value as NSNumber:
            // 必须先判别「真正的 JSON boolean」，再处理数值。
            //
            // Foundation 的桥接有个坑：`NSNumber(0)` 与 `NSNumber(1)` 都能
            // 先成功转换为 `Bool`，而真正的 JSON boolean 是 `__NSCFBoolean`
            // （CFBoolean）。若先匹配 `Bool`，合法的数值 0/1 会被改写成
            // `false` / `true`，`minimum` / `maximum` / `default` /
            // `const` / `examples` 里的数值全部失真。
            //
            // 用 CoreFoundation 的类型标识区分二者，不依赖 Swift 的桥接顺序。
            if CFGetTypeID(value) == CFBooleanGetTypeID() {
                return value.boolValue
            }
            // 整数值保持 Int，避免 3 变成 3.0 影响 Schema 的 `type` 语义。
            if CFNumberIsFloatType(value) {
                return value.doubleValue
            }
            return value.intValue
        case let value as [Any]:
            return value.map { convert($0) }
        case let value as [String: Any]:
            return value.mapValues { convert($0) }
        default:
            return String(describing: value)
        }
    }

    /// 转换字典为 `Sendable` 字典，供 chat template 直接使用。
    ///
    /// 空值的键**保留**（`"default": null` 里的 `default` 必须还在，只是
    /// 值为空）——删掉键会改变 Schema 的语义。
    static func convertSendableDictionary(_ value: [String: Any]) -> [String: any Sendable] {
        value.mapValues { convert($0) }
    }

    /// 转换字典为普通字典（保留 Foundation 值），用于诊断与测试。
    static func convertDictionary(_ value: [String: Any]) -> [String: Any] {
        value.mapValues { convert($0) }
    }
}
