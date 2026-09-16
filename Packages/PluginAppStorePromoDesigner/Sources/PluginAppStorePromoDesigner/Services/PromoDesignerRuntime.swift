import KitAgentTool
import Foundation
import KernelCore
import ProviderConversationInput
import ProviderProject

/// 宿主可注入的促销图设计评审 LLM 服务。
///
/// KernelCore 精简内核不内置 LLM provider，`review_image` 工具通过此协议
/// 调用宿主提供的视觉评审能力；未注入时工具返回「评审不可用」提示。
@MainActor
public protocol PromoDesignReviewLLMProviding: AnyObject, Sendable {
    /// 生成一次促销图设计评审。
    ///
    /// - Parameters:
    ///   - prompt: 资深设计师人设 + 结构化输出约束的评审提示词
    ///   - image: 渲染好的促销图 PNG
    /// - Returns: 评审正文
    func generateDesignReview(prompt: String, image: ImageAttachment) async throws -> String
}

@MainActor
enum PromoDesignerRuntime {
    static private(set) var projectStorageDirectory: URL?
    static private(set) var currentProjectPath: String?

    /// `review_image` 工具使用的 LLM 评审服务（宿主注入，可空）。
    static var designReviewLLM: (any PromoDesignReviewLLMProviding)?

    /// 聊天输入框服务（宿主注入，可空）。用于把选中的区块预填进输入框待发送。
    static var conversationInput: (any ConversationInputProviding)?

    static let projectFolderName = "app-store-promo"

    static func configure(kernel: KernelCoreContainer) {
        conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        updateProjectStorageDirectory(
            projectPath: kernel.resolveProvider((any ProjectProviding).self)?.currentProject?.path
        )
    }

    /// Called by the plugin-owned project observer when the active project changes.
    static func updateProjectStorageDirectory(projectPath: String?) {
        let normalizedPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let path = normalizedPath?.isEmpty == false ? normalizedPath : nil
        guard path != currentProjectPath || projectStorageDirectory != nil else { return }
        currentProjectPath = path
        let resolved = path.map {
            URL(fileURLWithPath: $0, isDirectory: true)
                .appendingPathComponent(".lumi", isDirectory: true)
                .appendingPathComponent(projectFolderName, isDirectory: true)
                .standardizedFileURL
        }
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

    /// 测试辅助：重置所有运行时状态及订阅。
    static func reset() {
        projectStorageDirectory = nil
        currentProjectPath = nil
        designReviewLLM = nil
        conversationInput = nil
        WorkspaceStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
