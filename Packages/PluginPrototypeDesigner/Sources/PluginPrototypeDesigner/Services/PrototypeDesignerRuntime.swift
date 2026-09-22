import Foundation
import KernelCore
import ProviderConversationInput
import ProviderProject
import ProviderToast
import os

/// 原型设计器的运行时状态。
///
/// 原型项目存储在当前项目的 `.lumi/prototype` 目录中；未打开项目时
/// 所有工具返回「需要先打开项目」。
@MainActor
enum PrototypeDesignerRuntime {
    static private(set) var projectStorageDirectory: URL?
    static private(set) var currentProjectPath: String?

    /// 当前项目内存储的文件夹名（`<项目>/.lumi/prototype`）。
    static let projectFolderName = "prototype"

    static func prototypeStorageDirectory(forProjectPath projectPath: String?) -> URL? {
        guard let path = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(projectFolderName, isDirectory: true)
            .standardizedFileURL
    }

    /// 聊天输入框服务（宿主注入，可空）。用于把选中的区块预填进输入框待发送。
    static var conversationInput: (any ConversationInputProviding)?
    /// 瞬时提示服务（宿主注入，可空）。用于发送到对话的成功 / 失败反馈。
    static var toast: (any ToastProviding)?

    static func configure(kernel: KernelCoreContainer) {
        conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        toast = kernel.resolveProvider((any ToastProviding).self)
        Logger(subsystem: "com.coffic.lumi.plugin.prototype-designer", category: "ConversationSend")
            .info("configure conversationInput=\(conversationInput != nil) toast=\(toast != nil)")
        print("[PrototypeDesigner] configure conversationInput=\(conversationInput != nil) toast=\(toast != nil)")
        updateProjectStorageDirectory(
            projectPath: kernel.resolveProvider((any ProjectProviding).self)?.currentProject?.path
        )
    }

    /// 由插件持有的项目观察者调用（当前项目变化时）。
    static func updateProjectStorageDirectory(projectPath: String?) {
        let normalizedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = normalizedPath?.isEmpty == false ? normalizedPath : nil
        guard path != currentProjectPath || projectStorageDirectory != nil else { return }
        currentProjectPath = path
        let resolved = prototypeStorageDirectory(forProjectPath: path)
        guard projectStorageDirectory != resolved else { return }
        projectStorageDirectory = resolved
        WorkspaceStore.shared.setProjectStorage(
            projectPath: path,
            projectStorageDirectory: resolved
        )
    }

    /// 测试辅助：手动注入项目路径与项目内存储目录。
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
        toast = nil
        WorkspaceStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
