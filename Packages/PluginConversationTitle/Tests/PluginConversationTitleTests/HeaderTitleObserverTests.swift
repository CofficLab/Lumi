import Foundation
import ProviderConversation
import Testing

@testable import PluginConversationTitle

/// Chat Header 标题展示链路测试：`ConversationEvent` → ViewModel。
///
/// Header 视图不订阅任何 Provider，标题完全由 Observer 推入 ViewModel。
/// 因此「哪些事件需要刷新」这条清单一旦被改动，标题就会在 UI 上滞后。
@Suite("Header 标题展示")
@MainActor
struct HeaderTitleObserverTests {

    // MARK: - ViewModel

    /// 相同标题重复写入应短路，避免无意义的 `objectWillChange` 触发重绘。
    @Test("ViewModel 相同标题重复写入短路")
    func viewModelSkipsDuplicateTitle() {
        let viewModel = ConversationTitleViewModel()

        var publishCount = 0
        let cancellable = viewModel.objectWillChange.sink { _ in publishCount += 1 }
        defer { cancellable.cancel() }

        viewModel.update(title: "标题")
        #expect(viewModel.title == "标题")
        let afterFirst = publishCount

        viewModel.update(title: "标题")
        #expect(publishCount == afterFirst)
    }

    /// 初始标题为空串。
    @Test("ViewModel 初始标题为空串")
    func viewModelStartsEmpty() {
        #expect(ConversationTitleViewModel().title == "")
    }

    // MARK: - Observer

    /// Observer 构造时立即同步一次当前标题。
    @Test("Observer 初始化时同步当前标题")
    func syncsInitialTitle() {
        let id = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: id)
        conversations.appendSummary(id: id, title: "已有标题")
        let viewModel = ConversationTitleViewModel()

        let observer = ConversationTitleHeaderObserver(
            conversations: conversations,
            viewModel: viewModel
        )
        defer { observer.cancel() }

        #expect(viewModel.title == "已有标题")
    }

    /// 所有 `ConversationEvent` 都应触发一次标题刷新。
    ///
    /// 这条用例守护的是 Observer 里的事件白名单：新增事件类型时若忘记
    /// 加入清单，标题不会更新，而这里会立刻失败。
    @Test("全部会话事件都触发标题刷新")
    func allEventsRefreshTitle() {
        let id = UUID()
        let other = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: id)
        conversations.appendSummary(id: id, title: "初始")
        conversations.appendSummary(id: other, title: "另一个会话")
        let viewModel = ConversationTitleViewModel()

        let observer = ConversationTitleHeaderObserver(
            conversations: conversations,
            viewModel: viewModel
        )
        defer { observer.cancel() }

        let events: [ConversationEvent] = [
            .created(other),
            .listChanged,
            .selected(other),
            .deleted(other),
            .updated(other),
            .markedActive(other),
            .providerChanged(other),
            .verbosityChanged(other),
            .reasoningChanged(other),
            .automationChanged(other),
            .languageChanged(other),
        ]

        for (index, event) in events.enumerated() {
            // 每次事件前切换选中态，令刷新结果可区分
            conversations.selected = index.isMultiple(of: 2) ? other : id
            conversations.emit(event)
            let expected = index.isMultiple(of: 2) ? "另一个会话" : "初始"
            #expect(viewModel.title == expected, "事件 \(event) 未刷新标题")
        }
    }

    /// 取消选择后标题应回落到空串（`currentTitle` 无匹配项）。
    @Test("取消选择后标题回落为空串")
    func clearsTitleOnDeselection() {
        let id = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: id)
        conversations.appendSummary(id: id, title: "旧标题")
        let viewModel = ConversationTitleViewModel()

        let observer = ConversationTitleHeaderObserver(
            conversations: conversations,
            viewModel: viewModel
        )
        defer { observer.cancel() }
        #expect(viewModel.title == "旧标题")

        conversations.selected = nil
        conversations.emit(.selected(nil))

        #expect(viewModel.title == "")
    }

    /// `cancel()` 应真正解除订阅：之后 Provider 再发事件，标题不应变化。
    @Test("cancel 后不再响应会话事件")
    func stopsAfterCancel() {
        let id = UUID()
        let other = UUID()
        let conversations = TitleTestDoubles.StubConversationManager(selected: id)
        conversations.appendSummary(id: id, title: "初始")
        conversations.appendSummary(id: other, title: "另一个会话")
        let viewModel = ConversationTitleViewModel()

        let observer = ConversationTitleHeaderObserver(
            conversations: conversations,
            viewModel: viewModel
        )
        #expect(conversations.isObserving)

        observer.cancel()
        #expect(!conversations.isObserving)

        conversations.selected = other
        conversations.emit(.selected(other))
        #expect(viewModel.title == "初始")
    }

    /// 重复 `cancel()` 不应崩溃。
    @Test("重复 cancel 幂等")
    func cancelIsIdempotent() {
        let conversations = TitleTestDoubles.StubConversationManager()
        let observer = ConversationTitleHeaderObserver(
            conversations: conversations,
            viewModel: ConversationTitleViewModel()
        )

        observer.cancel()
        observer.cancel()

        #expect(conversations.conversationHandle.cancelCount == 1)
    }
}
