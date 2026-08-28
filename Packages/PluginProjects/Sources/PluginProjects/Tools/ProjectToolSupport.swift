import KitAgentTool
import Foundation

/// Projects Agent 工具共享的辅助逻辑。
enum ProjectToolSupport {
    /// 读取整数参数（JSON 解码后可能是 Int / Double / String）。
    static func int(_ arguments: [String: ToolArgument], _ key: String) -> Int? {
        guard let value = arguments[key]?.value else { return nil }
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let string = value as? String { return Int(string) }
        return nil
    }

    /// 读取字符串参数。
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? {
        guard let value = arguments[key]?.value else { return nil }
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        return nil
    }

    /// 读取工具当前语言偏好（当前固定英文描述，与旧版一致）。
    static var language: LanguagePreference { .english }
}
