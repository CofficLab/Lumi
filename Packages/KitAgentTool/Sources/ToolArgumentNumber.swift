import Foundation

/// 工具参数的安全数值转换。
///
/// 工具参数来自 JSON，而 `JSONSerialization` 会把所有数字桥接成 `Double`。
/// 直接写 `Int(double)` 会在数值超出 `Int` 范围时触发 Swift 运行时陷阱
/// （precondition failure），直接终止宿主进程 —— 一个完全合法的 JSON 参数
/// 就能让应用崩溃。
///
/// 这里的转换一律先检查再转换，越界或非有限的值返回 `nil`，
/// 由调用方决定是拒绝、钳制还是使用默认值。
public enum ToolArgumentNumber {
    /// 把任意参数值安全地转换成 `Int`。
    ///
    /// - 接受 `Int`、`Double`、数字字符串。
    /// - `Double` 必须是有限值且落在 `Int` 范围内，否则返回 `nil`。
    /// - 非整数的 `Double`（如 `1.5`）向下取整。
    ///
    /// - Returns: 可安全表示的整数；无法表示时为 `nil`。
    public static func int(_ value: Any?) -> Int? {
        guard let value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return int(fromDouble: double) }
        if let string = value as? String {
            // 必须写 `Swift.Int(_:)`：裸写 `int(...)` 会解析到本枚举的
            // `int(_:)` 而不是 `Int.init?(String)`，造成无限递归（栈溢出）。
            return Swift.Int(string.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    /// 把 `Double` 安全地转换成 `Int`。
    ///
    /// 非有限值（`inf` / `nan`）与超出 `Int` 范围的值返回 `nil`。
    public static func int(fromDouble double: Double) -> Int? {
        guard double.isFinite else { return nil }
        // `Int(_:)` 在越界时 trap。用「与边界比较」而不是 `Double(Int.max)` 来判断 ——
        // 后者本身在某些平台上也会 trap（Double(Int.max) 不是精确可表示值）。
        // 精确的 Int 边界转成 Double 是 2^63（超出 Int.max）或 -2^63（等于 Int.min）。
        let upperBound = 9_223_372_036_854_775_808.0  // 2^63
        let lowerBound = -9_223_372_036_854_775_808.0 // -2^63
        guard double < upperBound, double >= lowerBound else { return nil }
        return Int(double)
    }

    /// 把任意参数值安全地转换成 `Int`，并钳制到给定区间。
    ///
    /// - Parameters:
    ///   - value: 原始参数值。
    ///   - range: 允许的闭区间。
    ///   - defaultValue: 值无法表示时使用的默认值。
    /// - Returns: 落在 `range` 内的整数。
    ///
    /// - Note: 无法安全表示的值（如 `1e100`、`nan`）退回默认值，
    ///   而不是被当作「超大但合法」的值钳制到上界 —— 前者是非法输入，
    ///   后者是一个合法的范围外请求，两者的处理方式不同。
    public static func int(
        _ value: Any?,
        clampedTo range: ClosedRange<Int>,
        default defaultValue: Int
    ) -> Int {
        guard let requested = int(value) else { return defaultValue }
        return min(max(requested, range.lowerBound), range.upperBound)
    }
}

extension Dictionary where Key == String, Value == ToolArgument {
    /// 读取整型参数；缺失或无法安全表示时返回 `nil`。
    public func toolInt(_ key: String) -> Int? {
        ToolArgumentNumber.int(self[key]?.value)
    }

    /// 读取整型参数并钳制到给定区间；缺失或无法安全表示时使用默认值。
    public func toolInt(
        _ key: String,
        clampedTo range: ClosedRange<Int>,
        default defaultValue: Int
    ) -> Int {
        ToolArgumentNumber.int(self[key]?.value, clampedTo: range, default: defaultValue)
    }
}
