import AppStorePromoKit
import Foundation
import LumiKernel

public struct PreviewPromoImageTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "app_store_promo_preview_image",
        displayName: "Preview promo image",
        description: "Render one promotional HTML image at an exact App Store size and attach the PNG for visual inspection."
    )
    public init() {}
    public var inputSchema: LumiJSONValue {
        var properties = PromoToolSupport.baseProperties(includeImage: true)
        properties["displayType"] = ["type": "string", "description": "Exact App Store display type. Defaults to the first preset for the task family."]
        return ["type": "object", "properties": .object(properties), "required": ["taskId", "imageId"]]
    }
    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        let scope = try await PromoToolSupport.resolveScope(arguments, kernel: kernel)
        let storagePath = try await PromoToolSupport.storagePath(for: scope)
        let image = try PromoToolSupport.store.readImage(
            storagePath: storagePath,
            taskSlug: try PromoToolSupport.required("taskId", arguments),
            imageSlug: try PromoToolSupport.required("imageId", arguments),
            localeIdentifier: arguments.string("localeIdentifier")
        )
        let type = arguments.string("displayType") ?? AppStorePromoDisplaySpec.presets(for: image.task.deviceFamily).first?.displayType
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
        kernel.attachImage(.init(mimeType: "image/png", base64Data: data.base64EncodedString(), fileName: "\(image.image.id)-\(image.localeIdentifier)-\(type).png"))
        return "Rendered promotional image at \(preset.width)x\(preset.height) for \(type) (scope=\(scope.rawValue), locale=\(image.localeIdentifier)). The PNG is attached for visual inspection."
    }
}
