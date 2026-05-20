import Foundation
import GoEditorCore
import EditorService

/// Go 语言集成能力。
///
/// 将 Go 项目的 module root、workspace folder 和 gopls 初始化选项交给通用 LSP 服务。
@MainActor
final class GoLanguageIntegrationCapability: SuperEditorLanguageIntegrationCapability {
    let id = "GoLanguageIntegration"
    let priority = 9

    func supports(languageId: String, projectPath: String?) -> Bool {
        guard languageId == "go" else { return false }
        guard GoLSPConfig.resolve() != nil else { return false }
        guard let projectPath else { return true }
        return GoProjectDetector.findProjectRoot(from: projectPath) != nil
    }

    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        guard languageId == "go" else { return nil }
        let root = GoProjectDetector.findProjectRoot(from: projectPath) ?? projectPath
        let url = URL(fileURLWithPath: root)
        return [EditorWorkspaceFolder(uri: url.absoluteString, name: url.lastPathComponent)]
    }

    func initializationOptions(for languageId: String, projectPath: String) -> [String: String]? {
        guard languageId == "go" else { return nil }
        return GoLSPConfig.resolve()?.initializationOptions
    }
}
