import Foundation

/// 子代理名字不合法或已被占用。
public enum SubagentIdentityError: Error, Equatable {
    case invalidName(String)
    case duplicateName(String)
}

/// 子代理的稳定名字（#1328 Task 1）。
///
/// 名字只在同一父会话的子代理之间比较：3-32 个字符，首字符必须是小写字母，
/// 其余允许小写字母、数字与连字符。名字一旦创建不再变化，也不做静默改写——
/// 非法或重名一律拒绝，由调用方决定换名。
public enum SubagentIdentity {
    public static let minLength = 3
    public static let maxLength = 32

    /// 与 `isValidName` 一致的 JSON Schema 正则，供工具声明使用。
    public static let pattern = "^[a-z][a-z0-9-]{2,31}$"

    public static func isValidName(_ name: String) -> Bool {
        guard (minLength...maxLength).contains(name.count),
              let first = name.unicodeScalars.first,
              isLowercaseLetter(first) else {
            return false
        }
        return name.unicodeScalars.dropFirst().allSatisfy { scalar in
            isLowercaseLetter(scalar) || isDigit(scalar) || scalar.value == 45
        }
    }

    /// 缺省名取第一个未被占用的 `agent-N`，不因中间空号继续增长。
    public static func defaultName(existing: [String]) -> String {
        let used = Set(existing)
        var index = 1
        while used.contains("agent-\(index)") {
            index += 1
        }
        return "agent-\(index)"
    }

    /// 解析最终名字：未提供时取默认名；提供时校验合法性与同级唯一性。
    public static func resolve(requested: String?, existing: [String]) throws -> String {
        guard let requested else {
            return defaultName(existing: existing)
        }
        guard isValidName(requested) else {
            throw SubagentIdentityError.invalidName(requested)
        }
        guard !existing.contains(requested) else {
            throw SubagentIdentityError.duplicateName(requested)
        }
        return requested
    }

    private static func isLowercaseLetter(_ scalar: Unicode.Scalar) -> Bool {
        (0x61...0x7A).contains(scalar.value)
    }

    private static func isDigit(_ scalar: Unicode.Scalar) -> Bool {
        (0x30...0x39).contains(scalar.value)
    }
}
