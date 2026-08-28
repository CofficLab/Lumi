import KitAgentTool
import Combine
import Foundation
import KernelCore
import ProviderProject
import ProviderStorage

/// 存储作用域：当前项目目录或应用级数据目录。
public enum IconScope: String, CaseIterable, Sendable {
    case project
    case app

    var rawName: String { rawValue }

    func displayName() -> String {
        switch self {
        case .project: AppIconDesignerLocalization.string("In Project")
        case .app: AppIconDesignerLocalization.string("In App")
        }
    }
}

/// 宿主可注入的图标设计评审 LLM 服务。
///
/// KernelCore 精简内核不内置 LLM provider，`review_icon` 工具通过此协议
/// 调用宿主提供的视觉评审能力；未注入时工具返回「评审不可用」提示。
@MainActor
public protocol IconDesignReviewLLMProviding: AnyObject, Sendable {
    /// 生成一次图标设计评审。
    ///
    /// - Parameters:
    ///   - prompt: 资深设计师人设 + 结构化输出约束的评审提示词
    ///   - image: 渲染好的图标 PNG
    /// - Returns: 评审正文
    func generateDesignReview(prompt: String, image: ImageAttachment) async throws -> String
}

@MainActor
enum IconDesignerRuntime {
    static private(set) var appStorageDirectory: URL?
    static private(set) var projectStorageDirectory: URL?
    static private(set) var currentProjectPath: String?

    /// `review_icon` 工具使用的 LLM 评审服务（宿主注入，可空）。
    static var designReviewLLM: (any IconDesignReviewLLMProviding)?

    private static var projectCancellable: AnyCancellable?
    static let projectFolderName = "app-icon-designer"

    static func configure(kernel: KernelCoreContainer, pluginID: String) {
        let appDirectory = kernel.resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: pluginID)
        configure(appStorageDirectory: appDirectory)
        installProjectObserver(kernel: kernel)
    }

    static func configure(appStorageDirectory: URL?) {
        let resolved = appStorageDirectory?.standardizedFileURL
        guard self.appStorageDirectory != resolved else { return }
        self.appStorageDirectory = resolved
        IconDocumentStore.shared.setAppStorage(appStorageDirectory: resolved)
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
        IconDocumentStore.shared.setProjectStorage(
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

    static func defaultScope(hasOpenProject: Bool? = nil) -> IconScope {
        (hasOpenProject ?? self.hasOpenProject) ? .project : .app
    }

    static func reset() {
        projectCancellable = nil
        appStorageDirectory = nil
        projectStorageDirectory = nil
        currentProjectPath = nil
        IconDocumentStore.shared.setAppStorage(appStorageDirectory: nil)
        IconDocumentStore.shared.setProjectStorage(
            projectPath: nil,
            projectStorageDirectory: nil
        )
    }
}
