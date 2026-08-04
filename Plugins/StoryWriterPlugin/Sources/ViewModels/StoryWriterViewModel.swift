import Foundation
import LumiKernel
import os
import SuperLogKit
import SwiftUI

/// View model for the Story Writer plugin.
///
/// Bridges `StoryStore` (actor) to SwiftUI views via `@Published` properties.
@MainActor
public final class StoryWriterViewModel: ObservableObject, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.story-writer.vm")
    public nonisolated static let emoji = "📖"
    nonisolated static let verbose = false

    private let store: StoryStore

    @Published public private(set) var stories: [Story] = []
    @Published public var currentStoryID: UUID?
    @Published public private(set) var chapters: [Chapter] = []
    @Published public private(set) var characters: [Character] = []

    /// Currently selected node in the outline (story, chapter, or character).
    @Published public var selectedNodeID: UUID?
    @Published public var selectedNodeKind: StoryWriterNodeKind?

    public init(store: StoryStore) {
        self.store = store
        observeExternalChanges()
    }

    // MARK: - External change observation

    private nonisolated(unsafe) var notificationObserver: NSObjectProtocol?

    private func observeExternalChanges() {
        // Agent tools post this notification after mutating the on-disk story
        // store. Reload everything to stay in sync.
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .storyWriterDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.reloadFromDisk()
            }
        }
    }

    deinit {
        if let token = notificationObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    /// Reload the in-memory snapshot from disk, preserving the current
    /// `currentStoryID` if it still exists.
    public func reloadFromDisk() async {
        let previousID = currentStoryID
        stories = await store.loadAllStories()
        if let previousID, stories.contains(where: { $0.id == previousID }) {
            await selectStory(id: previousID)
        } else if let first = stories.first {
            await selectStory(id: first.id)
        } else {
            await selectStory(id: nil)
        }
    }

    // MARK: - Stories

    public func loadStories() async {
        stories = await store.loadAllStories()
        if let first = stories.first, currentStoryID == nil {
            await selectStory(id: first.id)
        }
    }

    public func selectStory(id: UUID?) async {
        currentStoryID = id
        selectedNodeID = id
        selectedNodeKind = .story
        if let id {
            chapters = await store.loadChapters(storyID: id)
            characters = await store.loadCharacters(storyID: id)
        } else {
            chapters = []
            characters = []
        }
    }

    public func createStory(title: String) async -> Story {
        let story = await store.createStory(title: title)
        stories.insert(story, at: 0)
        await selectStory(id: story.id)
        return story
    }

    public func deleteStory(id: UUID) async {
        await store.deleteStory(id: id)
        stories.removeAll { $0.id == id }
        if currentStoryID == id {
            if let first = stories.first {
                await selectStory(id: first.id)
            } else {
                await selectStory(id: nil)
            }
        }
    }

    public func updateStory(_ story: Story) async {
        await store.updateStory(story)
        if let idx = stories.firstIndex(where: { $0.id == story.id }) {
            stories[idx] = story
        }
    }

    // MARK: - Chapters

    public func createChapter(title: String) async -> Chapter? {
        guard let storyID = currentStoryID else { return nil }
        guard let chapter = await store.createChapter(storyID: storyID, title: title) else { return nil }
        chapters.append(chapter)
        selectedNodeID = chapter.id
        selectedNodeKind = .chapter
        return chapter
    }

    public func deleteChapter(id: UUID) async {
        guard let storyID = currentStoryID else { return }
        await store.deleteChapter(id: id, storyID: storyID)
        chapters.removeAll { $0.id == id }
        if selectedNodeID == id {
            selectedNodeID = currentStoryID
            selectedNodeKind = .story
        }
    }

    public func updateChapter(_ chapter: Chapter) async {
        await store.updateChapter(chapter)
        if let idx = chapters.firstIndex(where: { $0.id == chapter.id }) {
            chapters[idx] = chapter
        }
    }

    // MARK: - Characters

    public func createCharacter(name: String) async -> Character? {
        guard let storyID = currentStoryID else { return nil }
        guard let character = await store.createCharacter(storyID: storyID, name: name) else { return nil }
        characters.append(character)
        selectedNodeID = character.id
        selectedNodeKind = .character
        return character
    }

    public func deleteCharacter(id: UUID) async {
        guard let storyID = currentStoryID else { return }
        await store.deleteCharacter(id: id, storyID: storyID)
        characters.removeAll { $0.id == id }
        if selectedNodeID == id {
            selectedNodeID = currentStoryID
            selectedNodeKind = .story
        }
    }

    public func updateCharacter(_ character: Character) async {
        await store.updateCharacter(character)
        if let idx = characters.firstIndex(where: { $0.id == character.id }) {
            characters[idx] = character
        }
    }

    // MARK: - Import / Export

    public func importMarkdownAsChapter(title: String, content: String) async -> Chapter? {
        guard let storyID = currentStoryID else { return nil }
        guard let chapter = await store.importMarkdownAsChapter(storyID: storyID, title: title, content: content) else {
            return nil
        }
        chapters.append(chapter)
        return chapter
    }

    public func exportStoryAsMarkdown() async -> String? {
        guard let storyID = currentStoryID else { return nil }
        return await store.exportStoryAsMarkdown(storyID: storyID)
    }

    // MARK: - Helpers

    public var currentStory: Story? {
        guard let id = currentStoryID else { return nil }
        return stories.first { $0.id == id }
    }

    public func selectedChapter() -> Chapter? {
        guard selectedNodeKind == .chapter, let id = selectedNodeID else { return nil }
        return chapters.first { $0.id == id }
    }

    public func selectedCharacter() -> Character? {
        guard selectedNodeKind == .character, let id = selectedNodeID else { return nil }
        return characters.first { $0.id == id }
    }
}
