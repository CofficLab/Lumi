import Foundation
import KitAgentTool
import KitPrototype

/// 以设备精确尺寸渲染一屏，并把 PNG 作为工具结果附件返回。
///
/// 这是「聊天画原型」的核心回路：模型改完 HTML 后调用本工具，
/// 就能在下一轮看到真实渲染结果并自我纠错。
public struct PreviewPrototypeScreenTool: SuperAgentTool {
    public let name = "prototype_preview_screen"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render one prototype screen at the project's device size and attach the PNG so you can inspect it visually. Call this after every HTML change."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": PrototypeToolSupport.baseProperties(includeScreen: true), "required": ["projectId", "screenId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PrototypeToolSupport.localized(PrototypeToolSupport.language, en: "Preview prototype screen", zh: "预览原型屏幕")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 覆盖默认实现：把渲染 PNG 作为图片附件放进结构化结果，供模型视觉检查。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let language = PrototypeToolSupport.language

        do {
            let storagePath = try await PrototypeToolSupport.storagePath()
            let resolved = try PrototypeToolSupport.store.readScreen(
                storagePath: storagePath,
                projectSlug: try PrototypeToolSupport.required("projectId", arguments),
                screenSlug: try PrototypeToolSupport.required("screenId", arguments)
            )
            let report = try PrototypeToolSupport.store.lintScreen(
                storagePath: storagePath,
                projectSlug: resolved.project.id,
                screenSlug: resolved.screen.id
            )
            guard report.isValid else { throw PrototypeStoreError.invalidHTML(report.errors) }

            let device = resolved.project.device
            let data = try await PrototypeHTMLExporter.exportPNG(
                html: resolved.html,
                fileURL: resolved.htmlURL,
                device: device
            )

            let warnings = report.warnings.isEmpty
                ? ""
                : "\nWarnings: " + report.warnings.map { "\($0.code) \($0.message)" }.joined(separator: " | ")
            let content = """
            Rendered screen '\(resolved.screen.id)' (\(resolved.screen.title)) \
            at \(Int(device.width))x\(Int(device.height))@\(device.scale)x → \(device.pixelWidth)x\(device.pixelHeight) px.
            The PNG is attached for visual inspection.\(warnings)
            """

            return ToolCallResult(
                content: content,
                images: [
                    ImageAttachment(
                        data: data,
                        mimeType: "image/png",
                        fileName: "\(resolved.project.id)-\(resolved.screen.id).png"
                    )
                ],
                isError: false
            )
        } catch {
            return ToolCallResult(
                content: PrototypeToolSupport.error(error, language: language),
                isError: true
            )
        }
    }
}
