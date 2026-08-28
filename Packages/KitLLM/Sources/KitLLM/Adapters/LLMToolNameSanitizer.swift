import Foundation

/// 工具名的供应商协议转义工具。
///
/// Anthropic / OpenAI 协议对 `tools[].name`（function name）都有严格校验：
/// - Anthropic 官方：`^[a-zA-Z0-9_-]{1,64}$`
/// - Kimi Coding 端点实测(2026-08-06)：必须以字母开头，且只允许
///   letters / numbers / underscores / dashes（违反直接 400：
///   "function name is invalid, must start with a letter..."）
///
/// 工具 id 来自插件注册（如 `app-store-connect.list-apps`）或 MCP
/// 服务器，可能含点号等非法字符，直接发送会被供应商拒绝。这里统一做
/// 字节级转义，并维护「sanitize 后名字 → 原始注册名」的映射，供流式响应
/// 解析时还原，保证工具调度仍按原始 id 执行。
public enum LLMToolNameSanitizer {
    /// 把工具名转义为供应商允许的字符集 `^[a-zA-Z0-9_-]+$`。
    ///
    /// - 采用 **ASCII 字节级** 校验（不能用 `Character.isLetter`，它会把中文等
    ///   Unicode 字母也判为合法，而服务端模式是纯 ASCII）；非法字节统一替换为 `_`
    /// - 若首字符不是字母（数字 / 下划线 / 短横线 / 非法字节），统一补 `tool_`
    ///   前缀，满足 Kimi 等端点「must start with a letter」的要求
    /// - 空名 / 全非法字符的兜底返回 `"tool"`
    public static func sanitize(_ raw: String) -> String {
        var result = ""
        result.reserveCapacity(raw.utf8.count + 5)
        for (index, byte) in raw.utf8.enumerated() {
            let isLetter = (byte >= 0x61 && byte <= 0x7A) || (byte >= 0x41 && byte <= 0x5A)
            let isLegal = isLetter ||
                (byte >= 0x30 && byte <= 0x39) || // 0-9
                byte == 0x5F ||                   // _
                byte == 0x2D                      // -
            if index == 0, !isLetter {
                result.append("tool_")
            }
            result.append(Character(UnicodeScalar(isLegal ? byte : 0x5F)))
        }
        return result.isEmpty ? "tool" : result
    }

    /// 建立「sanitize 后名字 → 原始注册名」的反查映射。
    ///
    /// 多个原始名映射到同一 sanitize 名时**先注册者优先**，保证反查确定性
    /// （与 DeepSeek 插件 `AnthropicRequestBuilder.toolNameMap` 的策略一致）。
    public static func reverseMap(for tools: [any LLMToolSchemaProviding]) -> [String: String] {
        var map: [String: String] = [:]
        for tool in tools {
            let sanitized = sanitize(tool.name)
            if map[sanitized] == nil {
                map[sanitized] = tool.name
            }
        }
        return map
    }
}
