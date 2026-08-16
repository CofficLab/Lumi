import AgentToolKit
import Foundation

/// Renders the selected vector document and returns the PNG as a tool-result
/// image attachment, allowing the model to inspect its own generated icon.
public struct PreviewIconTool: SuperAgentTool {
    public let name = "preview_icon"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render the current icon document as a PNG image and return it for visual inspection."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = IconToolSupport.baseProperties()
        properties["pixelSize"] = [
            "type": "integer",
            "description": "Optional square preview size in pixels. Defaults to 1024 and is capped at 2048."
        ]
        return ["type": "object", "properties": properties]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        "Preview icon"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 覆盖默认实现：把渲染 PNG 作为图片附件放进结构化结果，供模型视觉检查。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let language = IconToolSupport.language

        do {
            let (document, _) = try await IconToolSupport.resolveDocument(arguments)

            let requestedSize = IconToolSupport.double(arguments, "pixelSize", default: 1024)
            let pixelSize = Int(min(max(requestedSize, 64), 2048))
            let pngData = try await MainActor.run {
                try AppIconExportService().renderPreviewPNG(document: document, pixelSize: pixelSize)
            }

            let content = IconToolSupport.localized(
                language,
                en: "Rendered \(document.title) as a \(pixelSize)×\(pixelSize) PNG preview. The image is attached to this tool result for visual inspection.",
                zh: "已将 \(document.title) 渲染为 \(pixelSize)×\(pixelSize) PNG 预览图，图片已附加到工具结果中，可进行视觉检查。"
            )

            return ToolCallResult(
                content: content,
                images: [
                    ImageAttachment(
                        data: pngData,
                        mimeType: "image/png",
                        fileName: "\(document.fileSafeName)-preview.png"
                    )
                ],
                isError: false
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return ToolCallResult(
                content: IconToolSupport.error(error, language: language),
                isError: true
            )
        }
    }
}
