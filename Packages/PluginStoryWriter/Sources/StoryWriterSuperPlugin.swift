import KitAgentTool
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderConversationInput
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import ProviderToolManager
import SwiftUI
import KitSuperLog
import os

@MainActor
public final class StoryWriterSuperPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.story-writer", category: "StoryWriter")
    public let id = "com.coffic.lumi.plugin.story-writer"
    public let order = 90
    public let metadata = PluginMetadata(id: "com.coffic.lumi.plugin.story-writer", name: "Story Writer", description: "A two-pane workspace for crafting stories with AI assistance.", category: .project, stage: .preview, policy: .disabledByDefault)
    private let railID = "com.coffic.lumi.plugin.story-writer.outline"
    private let entryID = "com.coffic.lumi.plugin.story-writer.entry"
    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { StoryWriterAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { StoryWriterManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        let directory = kernel.resolveProvider((any StorageProviding).self)?.pluginDataDirectory(for: "StoryWriter")
        StoryWriterStorage.configureV2(directory: directory)
        let viewModel = StoryWriterViewModel(store: StoryStore(pluginDirectory: directory ?? FileManager.default.temporaryDirectory))
        RuntimeBridge.viewModel = viewModel
        RuntimeBridge.conversationInput = kernel.resolveProvider((any ConversationInputProviding).self)
        Task { await viewModel.loadStories() }

        let content = kernel.resolveProvider((any ContentViewProviding).self)
        let rail = kernel.resolveProvider((any RailViewProviding).self)
        rail?.addTabs([RailTabItem(id: railID, category: .project, title: LumiPluginLocalization.string("Story Outline", bundle: .module), systemImage: "list.bullet.rectangle.portrait", order: order) { StoryOutlineRootView() }])
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([ActivityBarItem(id: entryID, title: metadata.name, systemImage: "book.closed.fill", order: order, ownerPluginID: id) { state in
            guard state == .activated else { return }
            rail?.setVisibleTabID(self.railID)
            content?.setContentView(AnyView(StoryWriterRootView()))
        }])
        content?.setContentView(AnyView(StoryWriterRootView()))
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { StoryWriterAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { StoryWriterManualView() })
        }
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        StoryWriterV2Tool.all.forEach { tools?.add($0, pluginID: id) }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == entryID
        activityBar?.removeItems(ids: [entryID])
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [railID])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        StoryWriterV2Tool.all.forEach { tools?.remove(id: $0.name) }
        RuntimeBridge.viewModel = nil; RuntimeBridge.conversationInput = nil
        StoryWriterStorage.configureV2(directory: nil)
    }
}

public struct StoryWriterV2Tool: SuperAgentTool {
    public let name: String
    private let risk: CommandRiskLevel
    private init(_ name: String, risk: CommandRiskLevel) { self.name = name; self.risk = risk }
    public static let all = [
        StoryWriterV2Tool("list_stories", risk: .safe), StoryWriterV2Tool("get_story", risk: .safe), StoryWriterV2Tool("create_story", risk: .low), StoryWriterV2Tool("update_story", risk: .low), StoryWriterV2Tool("delete_story", risk: .medium),
        StoryWriterV2Tool("list_chapters", risk: .safe), StoryWriterV2Tool("get_chapter", risk: .safe), StoryWriterV2Tool("create_chapter", risk: .low), StoryWriterV2Tool("update_chapter", risk: .medium), StoryWriterV2Tool("delete_chapter", risk: .medium),
        StoryWriterV2Tool("import_markdown_as_chapter", risk: .low), StoryWriterV2Tool("export_story_as_markdown", risk: .safe),
    ]
    public func description(for language: LanguagePreference) -> String { "Story Writer tool: \(name.replacingOccurrences(of: "_", with: " "))." }
    public func inputSchema(for language: LanguagePreference) -> [String: Any] { ["type": "object", "properties": StoryWriterV2Support.properties(for: name), "additionalProperties": false] }
    public func displayDescription(for arguments: [String: ToolArgument]) -> String { name.replacingOccurrences(of: "_", with: " ") }
    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { risk }
    public func execute(arguments: [String: ToolArgument]) async throws -> String { await StoryWriterV2Support.execute(name: name, arguments: arguments) }
}

private enum StoryWriterV2Support {
    static func properties(for name: String) -> [String: Any] {
        var properties: [String: Any] = [:]
        if !["list_stories"].contains(name) { properties["story_id"] = ["type": "string"] }
        if ["get_story", "create_story", "update_story"].contains(name) { properties["title"] = ["type": "string"] }
        if ["create_story", "update_story"].contains(name) { properties["synopsis"] = ["type": "string"] }
        if name.contains("chapter") { properties["chapter_id"] = ["type": "string"]; properties["title"] = ["type": "string"]; properties["content"] = ["type": "string"]; properties["status"] = ["type": "string", "enum": ["draft", "in_progress", "done"]]; properties["target_word_count"] = ["type": "integer"] }
        return properties
    }
    static func string(_ arguments: [String: ToolArgument], _ key: String) -> String? { arguments[key]?.value as? String }
    static func id(_ arguments: [String: ToolArgument], _ key: String) -> UUID? { string(arguments, key).flatMap(UUID.init(uuidString:)) }
    static func integer(_ arguments: [String: ToolArgument], _ key: String) -> Int? { (arguments[key]?.value as? Int) ?? (arguments[key]?.value as? NSNumber)?.intValue }
    @MainActor static func store() -> StoryStore? { guard let directory = StoryWriterStorage.v2Directory else { return nil }; return StoryStore(pluginDirectory: directory) }
    static func execute(name: String, arguments: [String: ToolArgument]) async -> String {
        guard let store = await MainActor.run(body: { store() }) else { return "Error: Story Writer storage is not available." }
        switch name {
        case "list_stories": let stories = await store.loadAllStories(); return stories.isEmpty ? "No stories found. Use `create_story` to create the first one." : stories.map { "- **\($0.title)** (id: `\($0.id.uuidString)`)" }.joined(separator: "\n")
        case "get_story": guard let story = await findStory(store, arguments) else { return "Error: story not found" }; let chapters = await store.loadChapters(storyID: story.id); return "**\(story.title)**\n- id: `\(story.id.uuidString)`\n- chapters: \(chapters.count)\n\n**Synopsis:**\n\(story.synopsis)"
        case "create_story": guard let title = string(arguments, "title"), !title.isEmpty else { return "Error: title is required" }; var story = await store.createStory(title: title); if let synopsis = string(arguments, "synopsis") { story.synopsis = synopsis; await store.updateStory(story) }; changed(); return "✅ Created story **\(story.title)** (id: `\(story.id.uuidString)`)."
        case "update_story": guard let storyID = id(arguments, "story_id"), var story = await store.loadStory(id: storyID) else { return "Error: story not found" }; if let title = string(arguments, "title"), !title.isEmpty { story.title = title }; if let synopsis = string(arguments, "synopsis") { story.synopsis = synopsis }; await store.updateStory(story); changed(); return "✅ Updated story **\(story.title)**."
        case "delete_story": guard let storyID = id(arguments, "story_id") else { return "Error: valid story_id is required" }; await store.deleteStory(id: storyID); changed(); return "🗑️ Deleted story \(storyID.uuidString)."
        case "list_chapters": guard let storyID = id(arguments, "story_id") else { return "Error: valid story_id is required" }; let chapters = await store.loadChapters(storyID: storyID); return chapters.isEmpty ? "No chapters in this story yet." : chapters.enumerated().map { "\($0.offset + 1). **\($0.element.title)** — \($0.element.wordCount) words (id: `\($0.element.id.uuidString)`)" }.joined(separator: "\n")
        case "get_chapter": guard let chapter = await findChapter(store, arguments) else { return "Error: chapter not found" }; return "**\(chapter.title)**\n- id: `\(chapter.id.uuidString)`\n- status: \(chapter.status.rawValue)\n- target words: \(chapter.targetWordCount)\n\n**Content:**\n\(chapter.content)"
        case "create_chapter", "import_markdown_as_chapter": guard let storyID = id(arguments, "story_id"), let title = string(arguments, "title"), !title.isEmpty else { return "Error: valid story_id and title are required" }; let chapter = name == "import_markdown_as_chapter" ? await store.importMarkdownAsChapter(storyID: storyID, title: title, content: string(arguments, "content") ?? "") : await store.createChapter(storyID: storyID, title: title); guard var chapter else { return "Error: failed to create chapter (story may not exist)" }; if let content = string(arguments, "content") { chapter.content = content; chapter.status = content.isEmpty ? .draft : .inProgress }; if let target = integer(arguments, "target_word_count") { chapter.targetWordCount = target }; await store.updateChapter(chapter); changed(); return "✅ Created chapter **\(chapter.title)** (id: `\(chapter.id.uuidString)`)."
        case "update_chapter": guard let storyID = id(arguments, "story_id"), let chapterID = id(arguments, "chapter_id"), var chapter = await store.loadChapter(id: chapterID, storyID: storyID) else { return "Error: chapter not found" }; if let title = string(arguments, "title"), !title.isEmpty { chapter.title = title }; if let content = string(arguments, "content") { chapter.content = content }; if let target = integer(arguments, "target_word_count") { chapter.targetWordCount = target }; if let status = string(arguments, "status") { guard let value = ["draft": ChapterStatus.draft, "in_progress": .inProgress, "done": .done][status] else { return "Error: invalid status" }; chapter.status = value }; await store.updateChapter(chapter); changed(); return "✅ Updated chapter **\(chapter.title)** (\(chapter.wordCount) words)."
        case "delete_chapter": guard let storyID = id(arguments, "story_id"), let chapterID = id(arguments, "chapter_id") else { return "Error: valid story_id and chapter_id are required" }; await store.deleteChapter(id: chapterID, storyID: storyID); changed(); return "🗑️ Deleted chapter \(chapterID.uuidString)."
        case "export_story_as_markdown": guard let storyID = id(arguments, "story_id"), let markdown = await store.exportStoryAsMarkdown(storyID: storyID) else { return "Error: story not found" }; return "Exported story as Markdown:\n\n```\n\(markdown)\n```"
        default: return "Error: unknown Story Writer tool"
        }
    }
    static func findStory(_ store: StoryStore, _ arguments: [String: ToolArgument]) async -> Story? { if let storyID = id(arguments, "story_id") { return await store.loadStory(id: storyID) }; guard let title = string(arguments, "title") else { return nil }; return await store.loadAllStories().first { $0.title == title } }
    static func findChapter(_ store: StoryStore, _ arguments: [String: ToolArgument]) async -> Chapter? { guard let storyID = id(arguments, "story_id"), let chapterID = id(arguments, "chapter_id") else { return nil }; return await store.loadChapter(id: chapterID, storyID: storyID) }
    static func changed() { NotificationCenter.default.post(name: .storyWriterDidChange, object: nil) }
}
