import Foundation
import EditorService

@MainActor
final class JSLanguageIntegrationCapability: SuperEditorLanguageIntegrationCapability {
    let id = "JSLanguageIntegration"
    let priority = 8

    private let supportedLanguageIds: Set<String> = ["javascript", "typescript"]

    func supports(languageId: String, projectPath: String?) -> Bool {
        guard supportedLanguageIds.contains(languageId) else { return false }
        guard TSLSPConfig.config(projectPath: projectPath) != nil else { return false }
        guard let projectPath else { return true }
        return PackageJSONParser.parse(projectPath: projectPath) != nil
            || TSConfigResolver.resolve(projectPath: projectPath) != nil
    }

    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        let url = URL(fileURLWithPath: projectPath)
        return [EditorWorkspaceFolder(uri: url.absoluteString, name: url.lastPathComponent)]
    }

    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
        TSLSPConfig.config(projectPath: projectPath)?.initializationOptions
    }
}
