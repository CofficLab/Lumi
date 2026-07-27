import Foundation
import LumiKernel

/// Preview-time stub for `ProjectProviding` and `AppGitVM`.
///
/// 历史版本里这个文件还提供一个 `PreviewLumiCoreStub` 实现整个 `LumiCoreAccessing`,
/// 但那需要拉入 `StorageComponent` / `ProjectComponent` / `LayoutComponent` 等
/// 具体类型,违背"GitPlugin 与 kernel 解耦"的初衷。
///
/// 现在只暴露一个满足 `ProjectProviding` 协议的轻量级 stub。
/// `#Preview` 块只需要 `currentProject` —— 因此把另外三个写操作
/// (`openProject` / `closeProject` / `refreshProjects`) 留作 noop。

@MainActor
final class PreviewProjectProvidingStub: ProjectProviding {
    let currentProject: ProjectInfo?
    let projects: [ProjectInfo]

    init(
        currentProject: ProjectInfo? = PreviewProjectProvidingStub.previewProject,
        projects: [ProjectInfo] = []
    ) {
        self.currentProject = currentProject
        self.projects = projects
    }

    func openProject(at path: String) async throws {
        // Preview-only stub: 不响应真实项目切换。
    }

    func closeProject() async {
        // Preview-only stub.
    }

    func refreshProjects() async throws {
        // Preview-only stub.
    }

    static let previewProject = ProjectInfo(
        name: "Preview Project",
        path: "/tmp/preview-project",
        language: "swift"
    )
}

@MainActor
enum PreviewGitSupport {
    static let project: any ProjectProviding = PreviewProjectProvidingStub()
    static let gitVM = AppGitVM()
}
