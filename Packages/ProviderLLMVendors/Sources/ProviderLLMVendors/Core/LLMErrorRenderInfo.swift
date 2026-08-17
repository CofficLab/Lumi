import Foundation

/// 错误渲染元数据：错误类型可声明「该错误消息应如何渲染」。
///
/// AgentLoop 组装 error Message 时透传 `renderKind` / `rawErrorDetail`，
/// 渲染层据此匹配专用渲染器（如 API Key 缺失输入卡）。供应商层抛出的
/// 错误只需 conform 本协议即可被识别，无需耦合聊天消息类型。
public protocol LLMErrorRenderInfo {
    /// 指定渲染器 id / renderKind；`nil` 表示走默认错误渲染。
    var renderKind: String? { get }
    /// 原始错误详情（渲染器 Details 展开区展示）。
    var rawErrorDetail: String? { get }
}

/// 内置错误渲染类型常量（单一来源，AgentLoop 透传与渲染器引用同一处）。
public enum LLMErrorRenderKind {
    /// API Key 缺失 → 内联输入 Key 卡片。
    public static let apiKeyMissing = "llm-provider-api-key-missing"
    /// API Key 读取失败（Keychain 访问异常）。
    public static let apiKeyAccessFailed = "llm-provider-api-key-access-failed"
}
