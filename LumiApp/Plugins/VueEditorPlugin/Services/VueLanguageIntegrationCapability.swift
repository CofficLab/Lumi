import Foundation
import EditorService
import os

/// Vue 语言集成能力
///
/// 注册为 `SuperEditorLanguageIntegrationCapability`，让内核 LSPService
/// 知道当打开 `.vue` 文件时需要启动 Volar Language Server。
@MainActor
final class VueLanguageIntegrationCapability: SuperEditorLanguageIntegrationCapability {
    nonisolated static let emoji = "🟢"

    let id = "VueLanguageIntegration"
    let priority = 10

    /// 支持的语言 ID
    private let supportedLanguageIds: Set<String> = ["vue"]

    func supports(languageId: String, projectPath: String?) -> Bool {
        guard supportedLanguageIds.contains(languageId) else { return false }
        guard let projectPath else { return false }

        // 检查项目是否有 vue 依赖
        let packageJSONPath = (projectPath as NSString).appendingPathComponent("package.json")
        guard FileManager.default.fileExists(atPath: packageJSONPath) else { return false }

        return true
    }

    func workspaceFolders(for languageId: String, projectPath: String) -> [EditorWorkspaceFolder]? {
        // Volar 使用项目根目录作为 workspace
        let uri = URL(fileURLWithPath: projectPath).absoluteString
        let name = URL(fileURLWithPath: projectPath).lastPathComponent
        return [EditorWorkspaceFolder(uri: uri, name: name)]
    }

    func initializationOptions(for languageId: String, projectPath: String) -> [String : String]? {
        let version = VueVersionDetector.detect(at: projectPath)

        // 启用 Hybrid Mode（Volar 推荐）
        // Vue LS 仅处理 Template，Script 交给 TSServer
        return [
            "vue.server.hybridMode": "true",
            "vueVersion": version.rawValue == "vue2" ? "2" : "3",
        ]
    }
}
