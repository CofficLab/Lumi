import Foundation
import LumiKernel

/// Renders the selected vector document and returns the PNG as a tool-result
/// image attachment, allowing the model to inspect its own generated icon.
public struct PreviewIconTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "preview_icon",
        displayName: "Preview Icon",
        description: "Render the current icon document as a PNG image and return it for visual inspection."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        [
            "type": "object",
            "properties": [
                "pixelSize": [
                    "type": "integer",
                    "description": "Optional square preview size in pixels. Defaults to 1024 and is capped at 2048."
                ],
            ],
        ]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Preview icon"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel {
        .low
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let language = IconToolSupport.language(kernel)

        do {
            let document = try await MainActor.run {
                guard let document = IconDocumentStore.shared.selectedDocument else {
                    throw IconDocumentStoreError.noSelectedDocument
                }
                return document
            }

            let requestedSize = arguments.int("pixelSize") ?? 1024
            let pixelSize = min(max(requestedSize, 64), 2048)
            let pngData = try await MainActor.run {
                try AppIconExportService().renderPreviewPNG(document: document, pixelSize: pixelSize)
            }

            kernel.attachImage(
                LumiImageAttachment(
                    mimeType: "image/png",
                    base64Data: pngData.base64EncodedString(),
                    fileName: "(document.title)-preview.png"
                )
            )

            return IconToolSupport.localized(
                language,
                en: "Rendered (document.title) as a (pixelSize)×(pixelSize) PNG preview. The image is attached to this tool result for visual inspection.",
                zh: "已将 (document.title) 渲染为 (pixelSize)×(pixelSize) PNG 预览图，图片已附加到工具结果中，可进行视觉检查。"
            )
        } catch {
            await MainActor.run {
                IconDocumentStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }
}
