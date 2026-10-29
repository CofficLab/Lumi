import Foundation
import KernelCore
import ProviderConversationInput
import ProviderProject

/// 简历设计器的运行时状态（KernelCore 体系）。
///
/// 由旧版 `Plugins/ResumeDesignerPlugin/Sources/Services/Runtime.swift` 迁移而来。
/// 简历文档存储在当前项目的 `.lumi/resume-designer` 目录中。
@MainActor
enum ResumeDesignerRuntime {
    static private(set) var projectStorageDirectory: URL?
    static private(set) var currentProjectPath: String?

    static let projectFolderName = "resume-designer"

    /// 聊天输入框服务（宿主注入，可空）。用于把选中的区块预填进输入框待发送。
    static var conversationInput: (any ConversationInputProviding)?

    /// 指定项目路径对应的存储目录（`<项目>/.lumi/resume-designer`）。
    ///
    /// 纯函数：不依赖 UI 当前打开的项目，供工具按「调用所属对话的项目」解析路径。
    static func resumeStorageDirectory(forProjectPath projectPath: String?) -> URL? {
        guard let path = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(projectFolderName, isDirectory: true)
            .standardizedFileURL
    }

    static func configure(kernel: KernelCoreContainer) {
        conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        updateProjectStorageDirectory(
            projectPath: kernel.resolveProvider((any ProjectProviding).self)?.currentProject?.path
        )
    }

    static func updateProjectStorageDirectory(projectPath: String?) {
        let normalizedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = normalizedPath?.isEmpty == false ? normalizedPath : nil
        guard path != currentProjectPath || projectStorageDirectory != nil else { return }
        currentProjectPath = path
        let resolved = resumeStorageDirectory(forProjectPath: path)
        guard projectStorageDirectory != resolved else { return }
        projectStorageDirectory = resolved
        WorkspaceStore.shared.setProjectStorage(
            projectPath: path,
            projectStorageDirectory: resolved
        )
    }

    static func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        let normalizedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        currentProjectPath = normalizedPath?.isEmpty == false ? normalizedPath : nil
        let resolved = projectStorageDirectory?.standardizedFileURL
        self.projectStorageDirectory = resolved
        WorkspaceStore.shared.setProjectStorage(
            projectPath: currentProjectPath,
            projectStorageDirectory: resolved
        )
    }

    /// 测试辅助：重置所有运行时状态。
    static func reset() {
        projectStorageDirectory = nil
        currentProjectPath = nil
        conversationInput = nil
        WorkspaceStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
