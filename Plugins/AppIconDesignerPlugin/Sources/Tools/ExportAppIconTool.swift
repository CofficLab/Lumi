import Foundation
import KernelLumi

public struct ExportAppIconTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "export_app_icon",
        displayName: "Export App Icon",
        description: "Export the current App Icon Designer document or candidate image as an Xcode 26 AppIcon.icon that supports macOS 15 and later."
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        var properties = IconToolSupport.baseProperties()
        properties["artifactId"] = [
            "type": "string",
            "description": "Optional artifact id. Takes precedence over documentId. If omitted, a document or the currently selected candidate is exported."
        ]
        properties["outputDirectory"] = [
            "type": "string",
            "description": "Absolute directory path where AppIcon.icon should be created."
        ]
        properties["setName"] = [
            "type": "string",
            "description": "Optional icon set name. Defaults to AppIcon."
        ]
        return ["type": "object", "properties": .object(properties), "required": ["outputDirectory"]]
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "Export Xcode app icon"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .medium
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        let language = IconToolSupport.language(kernel)
        guard let outputDirectory = arguments["outputDirectory"]?.anyValue as? String, !outputDirectory.isEmpty else {
            return IconToolSupport.missingParameter("outputDirectory", language: language)
        }

        let requestedArtifactId = arguments["artifactId"]?.anyValue as? String
        let explicitDocumentId = arguments.string("documentId")?.trimmingCharacters(in: .whitespacesAndNewlines)
        let setName = (arguments["setName"]?.anyValue as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let outputURL = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        let resolvedName = setName?.isEmpty == false ? setName! : "AppIcon"

        do {
            // 1. 明确指定 artifact（最高优先级）。
            if let requestedArtifactId, !requestedArtifactId.isEmpty {
                let artifact = try await MainActor.run {
                    guard let artifact = AppIconArtifactStore.shared.artifacts.first(where: { $0.id == requestedArtifactId }) else {
                        throw ExportAppIconToolError.artifactNotFound(requestedArtifactId)
                    }
                    return artifact
                }
                let result = try IconComposerExportService().export(
                    sourceImagePath: artifact.sourcePath,
                    outputDirectory: outputURL,
                    name: resolvedName
                )
                await rememberExport(result)
                return exportSuccessMessage(language: language, url: result.iconURL)
            }

            // 2. 明确指定文档（按 documentId+scope 解析，缺失则报错）。
            if let explicitDocumentId, !explicitDocumentId.isEmpty {
                let (document, _) = try await IconToolSupport.resolveDocument(arguments, kernel: kernel)
                let result = try await MainActor.run {
                    try IconComposerExportService().export(document: document, outputDirectory: outputURL, name: resolvedName)
                }
                await rememberExport(result)
                return exportSuccessMessage(language: language, url: result.iconURL)
            }

            // 3. 回退：选中文档 → 选中 artifact → 报错。
            let exportSource = try await MainActor.run { () -> ExportSource in
                if let document = IconDocumentStore.shared.selectedDocument {
                    return ExportSource.document(document)
                }
                if let artifact = AppIconArtifactStore.shared.selectedArtifact {
                    return ExportSource.artifact(artifact)
                }
                throw ExportAppIconToolError.noSelectedSource
            }

            let service = IconComposerExportService()
            let result: IconComposerExportService.ExportResult
            switch exportSource {
            case .artifact(let artifact):
                result = try service.export(
                    sourceImagePath: artifact.sourcePath,
                    outputDirectory: outputURL,
                    name: resolvedName
                )
            case .document(let document):
                result = try await MainActor.run {
                    try service.export(document: document, outputDirectory: outputURL, name: resolvedName)
                }
            }

            await rememberExport(result)
            return exportSuccessMessage(language: language, url: result.iconURL)
        } catch {
            await MainActor.run {
                AppIconArtifactStore.shared.setError(error.localizedDescription)
            }
            return IconToolSupport.error(error, language: language)
        }
    }

    private func rememberExport(_ result: IconComposerExportService.ExportResult) async {
        await MainActor.run {
            AppIconArtifactStore.shared.setExportURL(result.iconURL)
            IconDocumentStore.shared.setExportURL(result.iconURL)
        }
    }

    private func exportSuccessMessage(language: LumiLanguagePreference, url: URL) -> String {
        IconToolSupport.localized(
            language,
            en: """
            Exported Xcode app icon.
            path: \(url.path)
            Add AppIcon.icon to an Xcode 26 project; Xcode generates the macOS 15 fallback automatically.
            """,
            zh: """
            已导出 Xcode App 图标。
            路径: \(url.path)
            将 AppIcon.icon 添加到 Xcode 26 项目；Xcode 会自动生成 macOS 15 兼容图标。
            """
        )
    }
}

private enum ExportSource {
    case artifact(AppIconArtifact)
    case document(IconDocument)
}

private enum ExportAppIconToolError: LocalizedError {
    case noSelectedSource
    case artifactNotFound(String)

    var errorDescription: String? {
        switch self {
        case .noSelectedSource:
            return "No app icon document or candidate is selected."
        case .artifactNotFound(let id):
            return "App icon artifact not found: \(id)"
        }
    }
}
