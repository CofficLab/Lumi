import Foundation
import KernelLumi

/// 根据自然语言描述，从零生成一个高保真、可交互的单文件 HTML 产品原型。
///
/// 工具内部调用当前选中的 LLM 生成原型（sub-agent 模式），把含 `<artifact>` 的
/// 回复作为结果返回；渲染器会提取其中的 HTML 并在聊天里渲染交互预览。
public struct GeneratePrototypeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "generate_prototype",
        displayName: "Generate Prototype",
        description: """
        根据自然语言描述，生成一个高保真、可交互的单文件 HTML 产品原型，并在聊天中渲染预览。\
        用于从零开始设计某个页面或界面（如登录页、商品列表、数据看板等）。
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "description": PrototypeToolSupport.stringProperty(
                    "想要设计的界面描述：包含哪些区域、核心功能、视觉风格、目标用户等，越具体越好。"
                ),
                "device": PrototypeToolSupport.enumProperty(
                    "目标设备，决定预览画框尺寸与设计基调。",
                    values: ["iphone", "ipad", "desktop"]
                )
            ]),
            "required": .array([.string("description")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let description = arguments.string("description") ?? ""
        return description.isEmpty ? "生成原型" : "生成原型：\(description)"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let description = arguments.string("description")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !description.isEmpty else {
            return "错误：缺少必需参数 description（界面描述）。"
        }
        let device = PrototypeToolSupport.device(from: arguments)

        let content: String
        do {
            content = try await PrototypeToolSupport.runGeneration(
                systemPrompt: PrototypePromptBuilder.generationSystemPrompt(device: device),
                userContent: description,
                kernel: kernel
            )
        } catch {
            return "生成失败：\(error.localizedDescription)"
        }

        guard let artifact = ArtifactExtractor.extract(from: content) else {
            return "未能从模型回复中解析出可渲染的原型产物，请尝试更具体的描述后重试。"
        }
        await PrototypeDesignerRuntime.shared.updateArtifact(artifact)

        return """
        已生成「\(artifact.title)」原型（\(artifact.device.displayName)），见下方预览。\
        如需调整，可直接描述修改，我会调用 refine_prototype 增量精修。

        \(content)
        """
    }
}
