import KitAgentTool
import Foundation
import KernelCore
import ProviderProject

/// 存储作用域：当前项目目录。
public enum IconScope: String, CaseIterable, Sendable {
    case project

    var rawName: String { rawValue }

    func displayName() -> String {
        AppIconDesignerLocalization.string("In Project")
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
    static private(set) var projectStorageDirectory: URL?
    static private(set) var currentProjectPath: String?

    /// `review_icon` 工具使用的 LLM 评审服务（宿主注入，可空）。
    static var designReviewLLM: (any IconDesignReviewLLMProviding)?

    static let projectFolderName = "app-icon-designer"

    /// 按对话项目隔离的 store 实例（key = 项目路径）。
    ///
    /// `IconDocumentStore.shared` 跟随 UI「当前打开的项目」。对话 A 的工具
    /// 调用若在用户切到对话 B 之后才执行，用 shared 就会写进 B 的项目。
    /// 因此对话项目与 UI 当前项目不同时，改用按对话项目目录配置的独立实例，
    /// 它的内存列表与落盘路径都只属于该对话的项目。
    private static var scopedStores: [String: IconDocumentStore] = [:]

    /// 指定项目路径对应的存储目录（`<项目>/.lumi/app-icon-designer`）。
    ///
    /// 纯函数：不依赖 UI 当前打开的项目，供工具按「调用所属对话的项目」解析路径。
    static func iconStorageDirectory(forProjectPath projectPath: String?) -> URL? {
        guard let path = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
            .appendingPathComponent(".lumi", isDirectory: true)
            .appendingPathComponent(projectFolderName, isDirectory: true)
            .standardizedFileURL
    }

    /// 取某个项目对应的 store：与 UI 当前项目一致时复用 shared，
    /// 否则返回按该项目目录配置的隔离实例。
    static func store(forProjectPath projectPath: String?) -> IconDocumentStore {
        guard let path = projectPath?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return IconDocumentStore.shared
        }
        let normalized = standardizedPath(path)
        guard let normalized else { return IconDocumentStore.shared }
        // 与 UI 当前打开的项目一致：直接用 shared，画布可实时看到 Agent 的改动。
        if normalized == standardizedPath(IconDocumentStore.shared.currentProjectPath) {
            return IconDocumentStore.shared
        }
        if let cached = scopedStores[normalized] {
            return cached
        }
        let store = IconDocumentStore()
        store.setProjectStorage(
            projectPath: normalized,
            projectStorageDirectory: iconStorageDirectory(forProjectPath: normalized)
        )
        scopedStores[normalized] = store
        return store
    }

    /// 标准化项目路径（两端统一后比较，避免尾斜杠等差异）。
    private static func standardizedPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL.path
    }

    static func configure(kernel: KernelCoreContainer) {
        updateProjectStorageDirectory(
            projectPath: kernel.resolveProvider((any ProjectProviding).self)?.currentProject?.path
        )
    }

    /// Called by the plugin-owned project observer when the active project changes.
    static func updateProjectStorageDirectory(projectPath: String?) {
        guard projectPath != currentProjectPath else { return }
        currentProjectPath = projectPath
        let resolved = iconStorageDirectory(forProjectPath: projectPath)
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
        .project
    }

    static func reset() {
        projectStorageDirectory = nil
        currentProjectPath = nil
        scopedStores.removeAll()
        IconDocumentStore.shared.setProjectStorage(
            projectPath: nil,
            projectStorageDirectory: nil
        )
    }
}
