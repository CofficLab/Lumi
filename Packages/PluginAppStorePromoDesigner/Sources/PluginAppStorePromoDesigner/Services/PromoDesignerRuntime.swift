import KitAgentTool
import Combine
import Foundation
import KernelCore
import ProviderConversationInput
import ProviderProject
import ProviderStorage

/// 存储作用域：当前项目目录或应用级数据目录。
public enum PromoScope: String, CaseIterable, Sendable {
    case project
    case app

    var rawName: String { rawValue }

    func displayName() -> String {
        switch self {
        case .project: PromoLocalization.string("In Project")
        case .app: PromoLocalization.string("In App")
        }
    }
}

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
    static private(set) var appStorageDirectory: URL?
    static private(set) var projectStorageDirectory: URL?
    static private(set) var currentProjectPath: String?

    /// `review_image` 工具使用的 LLM 评审服务（宿主注入，可空）。
    static var designReviewLLM: (any PromoDesignReviewLLMProviding)?

    /// 聊天输入框服务（宿主注入，可空）。用于把选中的区块预填进输入框待发送。
    static var conversationInput: (any ConversationInputProviding)?

    private static var projectCancellable: AnyCancellable?
    static let projectFolderName = "app-store-promo"

    static func configure(kernel: KernelCoreContainer, pluginID: String) {
        conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        let appDirectory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: pluginID)
        configure(appStorageDirectory: appDirectory)
        installProjectObserver(kernel: kernel)
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard self.appStorageDirectory != resolved else { return }
        self.appStorageDirectory = resolved
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: resolved)
    }

    private static func installProjectObserver(kernel: KernelCoreContainer) {
        projectCancellable = nil
        guard let project = kernel.resolveProvider((any ProjectProviding).self) else {
            currentProjectPath = nil
            updateProjectStorageDirectory(projectPath: nil)
            return
        }

        currentProjectPath = project.currentProject?.path
        updateProjectStorageDirectory(projectPath: currentProjectPath)
        projectCancellable = project.objectWillChange
            .sink { [weak project] _ in
                Task { @MainActor in
                    let newPath = project?.currentProject?.path
                    guard newPath != currentProjectPath else { return }
                    currentProjectPath = newPath
                    updateProjectStorageDirectory(projectPath: newPath)
                }
            }
    }

    private static func updateProjectStorageDirectory(projectPath: String?) {
        let resolved: URL?
        if let projectPath, !projectPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = URL(fileURLWithPath: projectPath, isDirectory: true)
                .appendingPathComponent(".lumi", isDirectory: true)
                .appendingPathComponent(projectFolderName, isDirectory: true)
                .standardizedFileURL
        } else {
            resolved = nil
        }
        guard projectStorageDirectory != resolved else { return }
        projectStorageDirectory = resolved
        WorkspaceStore.shared.setProjectStorage(
            projectPath: projectPath,
            projectStorageDirectory: resolved
        )
    }

    static var hasOpenProject: Bool {
        guard let path = currentProjectPath?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return false
        }
        return !path.isEmpty
    }

    /// 当 LLM 工具没有显式传 scope 时，根据是否有打开项目返回默认 scope。
    static func defaultScope(hasOpenProject: Bool? = nil) -> PromoScope {
        (hasOpenProject ?? self.hasOpenProject) ? .project : .app
    }

    /// 测试辅助：手动注入项目路径与项目内存储目录。
    static func setProjectStorage(projectPath: String?, projectStorageDirectory: URL?) {
        currentProjectPath = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = projectStorageDirectory?.standardizedFileURL
        guard self.projectStorageDirectory != resolved || currentProjectPath != (projectPath?.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        self.projectStorageDirectory = resolved
        WorkspaceStore.shared.setProjectStorage(projectPath: currentProjectPath, projectStorageDirectory: resolved)
    }

    /// 测试辅助：重置所有运行时状态（含 app / project 路径及订阅）。
    static func reset() {
        projectCancellable = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
        designReviewLLM = nil
        conversationInput = nil
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: nil)
        WorkspaceStore.shared.setProjectStorage(projectPath: nil, projectStorageDirectory: nil)
    }
}
