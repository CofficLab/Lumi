import Foundation

/// Storage operations the story writer view model depends on.
///
/// `StoryStore` is the production implementation; tests inject gated stubs
/// to construct late-arriving creation requests (issue #432).
public protocol StoryWriting: Sendable {
    func loadAllStories() async -> [Story]
    func createStory(title: String) async throws -> Story
    func updateStory(_ story: Story) async throws
    @discardableResult
    func deleteStory(id: UUID) async -> Bool
    func loadChapters(storyID: UUID) async -> [Chapter]
    func createChapter(storyID: UUID, title: String) async throws -> Chapter?
    func updateChapter(_ chapter: Chapter) async throws
    @discardableResult
    func deleteChapter(id: UUID, storyID: UUID) async throws -> Bool
    func loadCharacters(storyID: UUID) async -> [Character]
    func createCharacter(storyID: UUID, name: String) async throws -> Character?
    func updateCharacter(_ character: Character) async throws
    func deleteCharacter(id: UUID, storyID: UUID) async throws
    func importMarkdownAsChapter(storyID: UUID, title: String, content: String) async throws -> Chapter?
    func exportStoryAsMarkdown(storyID: UUID) async -> String?
}

extension StoryStore: StoryWriting {}