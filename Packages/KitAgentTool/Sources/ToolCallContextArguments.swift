import Foundation

/// 按工具契约裁剪历史工具调用参数，避免展示型载荷在后续回合重复进入模型上下文。
///
/// 只替换指定键的值；调用 ID、工具名与其余参数保持不变，因此历史里的
/// assistant tool call 与 tool result 仍然一一配对。
public enum ToolCallContextArguments {
    /// 被移出模型上下文的参数值统一替换成该占位字符串。
    public static let omissionPlaceholder = "[omitted from model context: already displayed to the user]"

    /// 返回可以送入模型上下文的参数 JSON。
    ///
    /// 参数不是合法 JSON 对象、或不需要裁剪任何键时，原样返回输入字符串，
    /// 保证不会把一次可用的历史改坏。
    public static func scrubbed(_ argumentsJSON: String, omitting keys: Set<String>) -> String {
        guard !keys.isEmpty,
              let data = argumentsJSON.data(using: .utf8),
              var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return argumentsJSON
        }

        var didOmit = false
        for key in keys where object[key] != nil {
            object[key] = omissionPlaceholder
            didOmit = true
        }
        guard didOmit,
              let scrubbed = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: scrubbed, encoding: .utf8) else {
            return argumentsJSON
        }
        return json
    }
}
