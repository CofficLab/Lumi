import Foundation
import KernelLumi

/// 构造原型设计专用的系统提示词，并把本地对话历史转换为内核 `LumiChatMessage`。
///
/// 核心策略（参考 v0 / Claude Artifacts 的产物约束）：
/// - 要求 LLM 把可渲染原型包在 `<artifact title="..." device="...">…</artifact>` 标签内；
/// - 强制单文件 HTML、内联样式、移动优先、零外部依赖，确保离线即可在 WKWebView 渲染；
/// - 修改时输出**完整**更新后的 artifact，便于 `ArtifactExtractor` 整体替换预览。
enum PrototypePromptBuilder {
    /// 约束 LLM 输出格式的系统提示词。
    static let systemPrompt = """
    你是一位资深的产品原型设计师与前端工程师，擅长把模糊的产品想法快速变成清晰、可交互的界面原型。

    # 你的职责
    通过对话帮用户进行产品原型设计：理解需求、梳理信息架构、产出可在预览区实时渲染的高保真原型，并支持多轮增量精修。

    # 输出格式（必须严格遵守）
    每次需要展示或修改界面时，把完整的原型放在一个 artifact 标签里：
    <artifact title="页面标题" device="iphone">
    <!DOCTYPE html>
    <html> …单文件 HTML… </html>
    </artifact>

    规则：
    1. 标签属性：`title` 为人类可读的页面标题；`device` 取值 `iphone` / `ipad` / `desktop`，默认 `iphone`。
    2. artifact 内部必须是**一个完整、自包含的 HTML 文件**：内联所有 CSS 与必需的 JS，**禁止引用任何外部 CDN、字体链接或网络资源**（预览环境完全离线）。
    3. 使用现代、克制、专业的视觉风格；移动优先、响应式；合理使用留白、圆角、阴影与一致的配色。
    4. 占位文案使用贴合场景的真实中文示例，不要写 Lorem ipsum。
    5. 纯展示型原型无需真实逻辑；如需交互，可用轻量内联 JS 模拟（切换 tab、展开折叠、表单校验提示等）。

    # 对话规则
    - 修改时，输出**更新后的完整 artifact**（不要只给 diff 或片段），让预览可以整体替换。
    - 在 artifact 标签**之外**，用 1-3 句中文简要说明你做了什么、以及可继续调整的方向。
    - 如果用户的需求还不清晰，先简短追问 1-2 个关键问题，再生成原型。
    - 优先围绕用户当前要做的页面工作，不要一次性堆砌无关功能。

    # 当前目标设备
    用户当前在预览：{DEVICE}（如无特别说明，按此设备设计）。
    """

    /// 把本地对话历史转换为内核消息列表（含系统提示词）。
    ///
    /// - Parameters:
    ///   - local: 本地对话历史。
    ///   - conversationID: 用于填充 `LumiChatMessage.conversationID` 的占位 ID（本插件不落库，仅为满足类型要求）。
    ///   - device: 当前选中的预览设备，注入到系统提示词。
    static func buildMessages(
        from local: [PrototypeMessage],
        conversationID: UUID,
        device: PrototypeArtifact.Device
    ) -> [LumiChatMessage] {
        var result: [LumiChatMessage] = [
            LumiChatMessage(
                conversationID: conversationID,
                role: .system,
                content: systemPrompt.replacingOccurrences(of: "{DEVICE}", with: device.displayName)
            )
        ]
        for message in local {
            let role: LumiChatMessageRole = (message.role == .user) ? .user : .assistant
            result.append(
                LumiChatMessage(
                    conversationID: conversationID,
                    role: role,
                    content: message.content
                )
            )
        }
        return result
    }
}
