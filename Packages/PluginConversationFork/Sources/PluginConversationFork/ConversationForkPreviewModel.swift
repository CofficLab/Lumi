import SwiftUI

/// 分叉弹窗的预览状态模型。
///
/// 预览加载是异步链路：`await coordinator.preview(for:)` 期间用户可能已经
/// 关掉弹窗又重开（源对话随之切换）。按仓库约定「捕获身份 → await → 写回前比对」，
/// 每次打开递增代次，写回前比对代次；旧请求的结果直接丢弃，
/// 既不发布预览，也不改动加载标记——否则弹窗会显示 A 的上下文，
/// 而确认按钮实际分叉的是 B（#463）。
@MainActor
final class ConversationForkPreviewModel: ObservableObject {
    @Published private(set) var preview: ConversationForkPreview?
    @Published private(set) var isLoading = false
    /// 打开弹窗时锁定的源对话 ID；确认分叉以它为准，不跟随当前选中对话。
    private(set) var target: UUID?

    private var revision = 0
    private let coordinator: ConversationForkCoordinator

    init(coordinator: ConversationForkCoordinator) {
        self.coordinator = coordinator
    }

    /// 打开弹窗：锁定源对话并启动预览加载。传 nil 表示没有选中对话。
    func open(for conversationID: UUID?) {
        revision += 1
        let currentRevision = revision
        target = conversationID
        preview = nil
        guard let conversationID else {
            isLoading = false
            return
        }
        isLoading = true
        let coordinator = self.coordinator
        Task { [weak self] in
            let result = await coordinator.preview(for: conversationID)
            guard let self, self.revision == currentRevision else { return }
            self.preview = result
            self.isLoading = false
        }
    }
}