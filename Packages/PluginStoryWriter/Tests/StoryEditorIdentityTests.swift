import Foundation
import SwiftUI
import Testing

@testable import StoryWriterPlugin

/// 故事编辑器的**视图 identity**回归测试（#289）。
///
/// ## 复现的缺陷
///
/// `StoryWriterView` 的 `.story` 分支原先直接渲染
/// `StoryEditorView(viewModel:story:)`，**没有** `.id(story.id)`，而相邻的
/// `.chapter` 分支却正确地加了 `.id(chapter.id)`。
///
/// `StoryEditorView` 把传入的故事拷进 `@State private var draft`
/// （`init` 里 `State(initialValue: StoryEditorDraft(story:))`）。SwiftUI 按
/// 视图 identity 缓存 `@State`：缺少故事专属 `.id` 时，从故事 A 切到故事 B
/// 会**复用同一个编辑器 identity**，`@State draft` 不被重新初始化，仍持有
/// A 的 id、基线与未保存简介。于是：
///
/// - 简介编辑经 `draft.storyToSave()` 落盘时仍带 **A 的 id** → 误写 A；
/// - 标题保存同样基于旧草稿 → 误写 A；
/// - 导出正文来自 ViewModel 的新选择（B），文件名却取自旧草稿/旧 story（A）
///   → 张冠李戴。
///
/// 修复：给 `.story` 分支补上 `.id(story.id)`，切换故事即重新物化编辑器，
/// `@State draft` 以新故事重新初始化，所有操作都指向当前故事。
///
/// ## 观测手段
///
/// 沿用本仓库 `MessageListStateLifetimeTests` 的做法：用 `Mirror` 反射
/// **求值后的 `body` 视图树**，在不改动生产代码、不依赖真实渲染的前提下
/// 断言结构不变式。`.id(x)` 在 SwiftUI 里物化为 `IDView<Content, ID>`，
/// 其 `content` 是被包裹的视图、`id` 是传入的标识值。测试递归查找包裹
/// `StoryEditorView` 的 `IDView`，读出它的 `id`：
///
/// - 缺少 `.id` 时查找返回 `nil` → 断言失败（修复前可复现）；
/// - `.id` 绑定到正确故事时返回该故事 id → 断言成立（修复后）。
///
/// 按**类型名字符串**匹配 `IDView`，测试在修复前后都能编译。
@MainActor
struct StoryEditorIdentityTests {

    // MARK: - 不变式 1：编辑器 identity 必须跟随当前选中的故事

    /// 切换故事后，包裹 `StoryEditorView` 的 identity 必须随之换成新故事的 id。
    ///
    /// 这是根因不变式：缺少故事专属 `.id` 时，编辑器 identity 不随故事变化，
    /// `@State draft` 被复用，简介更新/删除/导出文件名仍指向旧故事。
    @Test("故事编辑器 identity 跟随选中故事切换（回归 #289）")
    func storyEditorIdentityFollowsSelectedStory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let viewModel = StoryWriterViewModel(store: StoryStore(pluginDirectory: directory))

        let storyA = await viewModel.createStory(title: "A")
        let storyB = await viewModel.createStory(title: "B")
        #expect(storyA.id != storyB.id)

        await viewModel.selectStory(id: storyA.id)
        #expect(viewModel.selectedNodeKind == .story)
        let identityA = storyEditorIdentity(in: StoryWriterView(viewModel: viewModel).body)
        #expect(
            identityA == storyA.id,
            "选中 A 时编辑器必须带 A 的 identity，实际为 \(String(describing: identityA))；缺少 .id(story.id) 会复用旧草稿，误写/误删 A"
        )

        await viewModel.selectStory(id: storyB.id)
        let identityB = storyEditorIdentity(in: StoryWriterView(viewModel: viewModel).body)
        #expect(
            identityB == storyB.id,
            "切到 B 时编辑器 identity 必须换成 B，实际为 \(String(describing: identityB))"
        )
        #expect(identityA != identityB, "切换故事必须改变编辑器 identity，否则 @State 草稿不被重置")
    }

    // MARK: - 不变式 2：同一故事多次渲染 identity 必须稳定

    /// 故事不变时，编辑器 identity 必须在多次 body 求值之间保持稳定。
    ///
    /// 防止把修复写成 `.id(UUID())` 之类的不稳定标识：那会让每次重绘都重建
    /// 编辑器、清空用户正在输入的草稿。identity 必须且只须绑定 `story.id`。
    @Test("同一故事多次渲染编辑器 identity 保持稳定（回归 #289）")
    func storyEditorIdentityIsStableAcrossRendersForSameStory() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let viewModel = StoryWriterViewModel(store: StoryStore(pluginDirectory: directory))

        let story = await viewModel.createStory(title: "A")
        guard let chapter = await viewModel.createChapter(title: "Opening") else {
            Issue.record("Could not create chapter")
            return
        }
        await viewModel.selectStory(id: story.id)

        let first = storyEditorIdentity(in: StoryWriterView(viewModel: viewModel).body)
        #expect(first == story.id)

        // 触发一次与故事 identity 无关的发布变化（章节内容更新），再求值 body。
        var edited = chapter
        edited.content = "new body"
        await viewModel.updateChapter(edited)
        let second = storyEditorIdentity(in: StoryWriterView(viewModel: viewModel).body)
        #expect(
            second == story.id,
            "故事未变时 identity 必须稳定，否则每次重绘都会清空用户草稿"
        )
        #expect(first == second)
    }

    // MARK: - 不变式 3：重新物化的草稿必须绑定新故事

    /// `.id(story.id)` 在切换故事时强制重建编辑器，新草稿以新故事初始化。
    /// 本用例锁定该重建带来的用户可见保证：新草稿不带旧故事的未保存简介，
    /// 落盘只指向新故事。
    @Test("切换故事后重建的草稿绑定新故事且不含旧故事未保存编辑（回归 #289）")
    func reMaterializedEditorDraftBindsToNewStory() {
        let storyA = Story(title: "A", synopsis: "A synopsis")
        let storyB = Story(title: "B", synopsis: "B synopsis")

        // 旧编辑器里 A 的草稿尚有未保存简介。
        var oldDraft = StoryEditorDraft(story: storyA)
        oldDraft.updateSynopsis("A + unsaved user edit")
        #expect(oldDraft.hasUnsavedSynopsis)
        #expect(oldDraft.storyToSave().id == storyA.id)

        // 切到 B：.id(story.id) 重新物化编辑器 → 以 B 全新初始化的草稿。
        let newDraft = StoryEditorDraft(story: storyB)
        #expect(newDraft.baseStory.id == storyB.id)
        #expect(newDraft.synopsis == storyB.synopsis)
        #expect(!newDraft.hasUnsavedSynopsis, "新故事的草稿不得继承旧故事的未保存简介")

        let saved = newDraft.storyToSave()
        #expect(saved.id == storyB.id, "落盘必须指向新故事 B，绝不能误写旧故事 A")
        #expect(saved.id != storyA.id)
        #expect(saved.synopsis == storyB.synopsis)
    }
}

// MARK: - Mirror 观测辅助

/// 递归判断视图树中是否含有 `StoryEditorView`。
private func containsStoryEditor(_ value: Any) -> Bool {
    if value is StoryEditorView { return true }
    for child in Mirror(reflecting: value).children where containsStoryEditor(child.value) {
        return true
    }
    return false
}

/// 在求值后的 body 视图树里，查找包裹 `StoryEditorView` 的 `.id` 标识值。
///
/// `.id(x)` 物化为 `IDView<Content, ID>`：`content` 是被包裹视图、`id` 是标识。
/// 找到 content 含 `StoryEditorView` 的 `IDView` 即返回其 `id`；找不到返回 `nil`
/// （即编辑器没有故事专属 identity —— 正是 #289 的缺陷形态）。
private func storyEditorIdentity(in value: Any) -> UUID? {
    let typeName = String(describing: type(of: value))
    if typeName.contains("IDView") {
        var content: Any?
        var identity: UUID?
        for child in Mirror(reflecting: value).children {
            if child.label == "content" { content = child.value }
            if child.label == "id" { identity = child.value as? UUID }
        }
        if let content, containsStoryEditor(content), let identity {
            return identity
        }
    }
    for child in Mirror(reflecting: value).children {
        if let found = storyEditorIdentity(in: child.value) { return found }
    }
    return nil
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("StoryEditorIdentityTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}