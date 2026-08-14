import Foundation
import KernelLumi

/// 基于当前原型，按修改指令进行增量调整。
///
/// 读取 `PrototypeDesignerRuntime.shared.currentArtifact` 作为基线，连同修改要求
/// 一并交给 LLM，输出更新后的完整原型。未提及的部分会被保留，避免破坏性全量重生成。
public struct RefinePrototypeTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "refine_prototype",
        displayName: "Refine Prototype",
        description: """
        基于当前原型，按修改指令进行增量调整（增删元素、改样式、调布局、换配色等）。\
        会保留未提及的部分。需要先用 generate_prototype 生成一个原型。
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "changes": PrototypeToolSupport.stringProperty(
                    "要对当前原型做的修改描述，例如「在登录按钮下方加一个忘记密码链接」「把主色改成绿色」。"
                ),
                "device": PrototypeToolSupport.enumProperty(
                    "可选：顺带切换目标设备。",
                    values: ["iphone", "ipad", "desktop"]
                )
            ]),
            "required": .array([.string("changes")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let changes = arguments.string("changes") ?? ""
        return changes.isEmpty ? "精修原型" : "精修原型：\(changes)"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        guard let changes = arguments.string("changes")?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !changes.isEmpty else {
            return "错误：缺少必需参数 changes（修改描述）。"
        }
        guard let current = await PrototypeDesignerRuntime.shared.currentArtifact else {
            return "当前还没有原型。请先用 generate_prototype 生成一个，再进行精修。"
        }
        let device = PrototypeToolSupport.device(from: arguments)

        let userContent = """
        下面是当前原型（目标设备：\(device.displayName)），请在其基础上按修改要求调整，\
        输出更新后的完整 <artifact>。务必保留用户未提及的部分，只改动相关内容。

        <artifact title="\(current.title)" device="\(current.device.rawValue)">
        \(current.html)
        </artifact>

        修改要求：
        \(changes)
        """

        let content: String
        do {
            content = try await PrototypeToolSupport.runGeneration(
                systemPrompt: PrototypePromptBuilder.generationSystemPrompt(device: device),
                userContent: userContent,
                kernel: kernel
            )
        } catch {
            return "修改失败：\(error.localizedDescription)"
        }

        guard let artifact = ArtifactExtractor.extract(from: content) else {
            return "未能从模型回复中解析出更新后的原型，请重试。"
        }
        await PrototypeDesignerRuntime.shared.updateArtifact(artifact)

        return """
        已按「\(changes)」更新原型，见下方预览。

        \(content)
        """
    }
}
