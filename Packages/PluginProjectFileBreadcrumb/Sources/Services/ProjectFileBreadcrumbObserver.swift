import Combine
import Foundation
import KernelLumi

/// 面包屑导航状态订阅适配器。
///
/// Phase 3 迁移（重构方案 §17.2）：当前文件来自 Editor Session 状态
/// （`kernel.editorV2.documents`，单一事实源）；项目根仍来自
/// `ProjectProviding.currentProject`（项目身份属于 Project）。
/// 两个流任一变化都触发视图刷新；视图在 body 内实时读取派生值，
/// 规避 `objectWillChange` 触发时值仍为旧的陷阱。
@MainActor
final class ProjectFileBreadcrumbObserver: ObservableObject {
    /// 当前活动文档 URI（Editor 契约 V2）。
    @Published private(set) var activeFileURL: URL?

    private var documentCancellable: AnyCancellable?
    private var projectCancellable: AnyCancellable?

    init(kernel: KernelLumi) {
        // CurrentValue 语义：订阅即收到当前快照。
        documentCancellable = kernel.editorV2?.documents.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.activeFileURL = state.activeDocument?.uri.standardizedFileURL
            }
        projectCancellable = kernel.project?.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
    }
}
