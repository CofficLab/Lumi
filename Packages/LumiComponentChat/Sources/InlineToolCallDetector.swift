import Foundation

/// 检测模型是否把工具调用以特殊格式写进了正文文本，
/// 而非通过结构化的 `tool_use` / `tool_calls` 接口返回。
///
/// 某些模型（或经第三方网关转发时）会泄漏下列格式到 `content` 正文里：
/// - Hermes / llama 风格：`<tool_call>...</tool_call>`
/// - Anthropic 泄漏：`<function_calls>` / `<antml:function_calls>` / `<antml:parameter>`
/// - Qwen / Mistral 代码块：` ```tool_call ` / ` ```json ` 内含 `{"name":...,"arguments":...}`
/// - 纯 JSON 行：`{"name":"xxx","arguments":...}`
/// - MCP 风格：`<use_mcp_tool>` / `<invoke>`
///
/// 这类正文会让 `AssistantMessage.toolCalls` 为空，
/// 导致 `AgentLoop` 误判「没有工具调用」而提前结束。
public enum InlineToolCallDetector {

    /// 命中即判真的标签类格式（几乎不会出现在正常正文里，误判率极低）。
    private static let tagPatterns: [NSRegularExpression] = {
        let patterns = [
            #"<tool_call[\s>]"#,                 // <tool_call> / <tool_call ...>
            #"</tool_call\s*>"#,                 // 闭合标签（兼容属性/空白）
            #"<function_calls[\s>]"#,            // <function_calls>
            #"<\s*antml:function_calls[\s>]"#,   // <antml:function_calls>
            #"<\s*antml:parameter[\s>]"#,        // <antml:parameter ...>
            #"<use_mcp_tool[\s>]"#,              // <use_mcp_tool>
            #"<invoke[\s>]"#,                    // <invoke>（MCP XML 风格）
            #"```tool_call"#,                    // ```tool_call 代码块
        ]
        return patterns.compactMap { pattern in
            try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        }
    }()

    /// 纯 JSON 工具调用格式：要求同时含 `name` 与 `arguments`/`parameters` 键。
    /// 用宽松正则先粗筛，再用 `JSONSerialization` 复核，避免误判普通 JSON 说明文本。
    private static let jsonToolCallPattern: NSRegularExpression = {
        // 匹配 {"name":"...","arguments":...} 或 {"name":"...","parameters":...}
        // 键顺序不限、允许空白；arguments/parameters 值可以是对象或字符串。
        let pattern = #"\{\s*"[^"]*"\s*:\s*"[^"]*"\s*,\s*"[^"]*"\s*:\s*[\{\"]"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    /// 检测正文里是否出现了本该走结构化 `tool_use` 的工具调用格式。
    ///
    /// - Note: 仅做格式检测，不校验工具名是否存在。调用方应先确认
    ///   `assistantMessage.toolCalls` 为空（模型确实没返回结构化工具调用），
    ///   再据此判断是否需要纠正重试。
    public static func detected(in content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let range = NSRange(trimmed.startIndex..., in: trimmed)

        // 1. 标签类格式：命中任一即判真。
        for regex in tagPatterns {
            if regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                return true
            }
        }

        // 2. 纯 JSON 工具调用：粗筛 + 结构复核。
        //    找到所有候选 JSON 对象，确认同时含 name 与 arguments/parameters 键。
        if let jsonCandidates = extractTopLevelJSONObjects(in: trimmed) {
            for candidate in jsonCandidates {
                if looksLikeToolCallJSON(candidate) {
                    return true
                }
            }
        }

        return false
    }

    /// 从正文中提取所有「看起来像顶层 JSON 对象」的子串并尝试解析。
    ///
    /// 采用括号配平扫描而非正则全文匹配，以正确处理嵌套对象（如 arguments 是个对象）。
    private static func extractTopLevelJSONObjects(in text: String) -> [[String: Any]]? {
        var results: [[String: Any]] = []
        let scalars = Array(text.unicodeScalars)
        var i = 0
        while i < scalars.count {
            guard scalars[i] == "{" else {
                i += 1
                continue
            }
            // 从这个 `{` 开始做括号配平，提取一个候选 JSON 对象子串。
            var depth = 0
            var inString = false
            var escape = false
            var j = i
            while j < scalars.count {
                let c = scalars[j]
                if inString {
                    if escape {
                        escape = false
                    } else if c == "\\" {
                        escape = true
                    } else if c == "\"" {
                        inString = false
                    }
                } else {
                    if c == "\"" {
                        inString = true
                    } else if c == "{" {
                        depth += 1
                    } else if c == "}" {
                        depth -= 1
                        if depth == 0 {
                            break
                        }
                    }
                }
                j += 1
            }
            // j 停在配平的 `}` 上；提取 [i...j] 子串。
            if j < scalars.count && depth == 0 {
                let startIdx = text.index(text.startIndex, offsetBy: i)
                let endIdx = text.index(text.startIndex, offsetBy: j + 1)
                let candidate = String(text[startIdx..<endIdx])
                if let data = candidate.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    results.append(obj)
                }
            }
            i = j + 1
        }
        return results.isEmpty ? nil : results
    }

    /// 判断一个已解析的 JSON 对象是否符合「工具调用」结构。
    ///
    /// 要求同时含 `name`（字符串）与 `arguments`/`parameters`（对象或字符串）键。
    /// 这是最常见的 OpenAI / Hermes / Qwen 内联工具调用 JSON 形态。
    private static func looksLikeToolCallJSON(_ object: [String: Any]) -> Bool {
        let hasName = (object["name"] as? String)?.isEmpty == false
            || (object["tool"] as? String)?.isEmpty == false
        let hasArgs = object["arguments"] != nil || object["parameters"] != nil
        return hasName && hasArgs
    }
}
