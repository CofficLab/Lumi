import KitAgentTool
import Foundation

/// 工具参数编解码：在 `ToolCall.arguments`（JSON 字符串）与
/// `SuperAgentTool.execute` 接收的 `[String: ToolArgument]` 之间转换。
///
/// `ToolArgument` 是 `Any` 的包装器，因此这里使用 `JSONSerialization`
/// 保留 JSON 的原始形态（字符串/数字/布尔/数组/字典/null）。
public enum ToolArgumentCoding {
    /// 将 JSON 字符串解码为参数字典。空字符串视为空参数字典。
    /// 非对象 JSON（数组、标量）视为解码失败。
    /// 容错处理：如果 JSON 格式错误（如多个对象拼接 "{}{\"key\":\"value\"}"），
    /// 尝试提取最后一个有效的 JSON 对象。
    public static func decode(_ json: String) throws -> [String: ToolArgument] {
        guard let data = json.data(using: .utf8), !data.isEmpty else { return [:] }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: [],
                    debugDescription: "Tool arguments must be a JSON object"
                ))
            }
            return dictionary.mapValues { ToolArgument($0) }
        } catch {
            // 容错：尝试提取最后一个有效的 JSON 对象
            // 兼容 LLM 输出格式错误，如 "{}{\"path\":\"...\"}"
            if let lastObjectRange = json.range(of: "\\{[^{}]*\\}$", options: .regularExpression),
               let subData = String(json[lastObjectRange]).data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: subData),
               let dictionary = object as? [String: Any] {
                return dictionary.mapValues { ToolArgument($0) }
            }
            throw error
        }
    }

    /// 将参数字典编码回 JSON 字符串（记录用）。失败时回退 `"{}"`。
    public static func encode(_ arguments: [String: ToolArgument]) -> String {
        let values = arguments.mapValues(\.value)
        guard JSONSerialization.isValidJSONObject(values),
              let data = try? JSONSerialization.data(withJSONObject: values),
              let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }

    /// 解码失败时用于日志/记录的原始参数字符串（截断保护）。
    public static func sanitized(_ json: String) -> String {
        String(json.prefix(4_000))
    }
}
