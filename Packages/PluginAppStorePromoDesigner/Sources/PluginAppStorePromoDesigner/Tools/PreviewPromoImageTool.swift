import AgentToolKit
import AppStorePromoKit
import Foundation

/// 在精确的 App Store 尺寸下渲染促销图 HTML，并把 PNG 作为工具结果附件返回。
public struct PreviewPromoImageTool: SuperAgentTool {
    public let name = "app_store_promo_preview_image"

    public init() {}

    public func description(for language: LanguagePreference) -> String {
        "Render one promotional HTML image at an exact App Store size and attach the PNG for visual inspection."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        return ["type": "object", "properties": properties, "required": ["taskId", "imageId"]]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        PromoToolSupport.localized(PromoToolSupport.language, en: "Preview promo image", zh: "预览促销图")
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    /// 覆盖默认实现：把渲染 PNG 作为图片附件放进结构化结果，供模型视觉检查。
    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let language = PromoToolSupport.language

        do {
            let scope = try await PromoToolSupport.resolveScope(arguments)
            let storagePath = try await PromoToolSupport.storagePath(for: scope)
            let image = try PromoToolSupport.store.readImage(
                storagePath: storagePath,
                taskSlug: try PromoToolSupport.required("taskId", arguments),
                imageSlug: try PromoToolSupport.required("imageId", arguments),
                localeIdentifier: PromoToolSupport.string(arguments, "localeIdentifier")
            )
            let type = PromoToolSupport.string(arguments, "displayType")
                ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
            guard let type, let preset = AppStorePromoDisplaySpec.preset(for: type), preset.family == image.task.deviceFamily else {
                throw PromoToolSupport.ToolArgumentError.invalid("displayType")
            }
            let report = try PromoToolSupport.store.lintImage(
                storagePath: storagePath,
                taskSlug: image.task.id,
                imageSlug: image.image.id,
                localeIdentifier: image.localeIdentifier
            )
            guard report.isValid else { throw AppStorePromoStoreError.invalidHTML(report.errors) }
            let data = try await AppStorePromoHTMLExporter.exportPNG(html: image.html, fileURL: image.htmlURL, preset: preset)

            let content = "Rendered promotional image at \(preset.width)x\(preset.height) for \(type) (scope=\(scope.rawValue), locale=\(image.localeIdentifier)). The PNG is attached for visual inspection."
            return ToolCallResult(
                content: content,
                images: [
                    ImageAttachment(
                        data: data,
                        mimeType: "image/png",
                        fileName: "\(image.image.id)-\(image.localeIdentifier)-\(type).png"
                    )
                ],
                isError: false
            )
        } catch {
            return ToolCallResult(
                content: PromoToolSupport.error(error, language: language),
                isError: true
            )
        }
    }
}
