import Foundation

/// Storage operations the story writer view model depends on.
///
/// `StoryStore` is the production implementation; tests inject gated stubs
/// to construct late-arriving creation requests (issue #432).
public protocol StoryWriting: Sendable {
    func loadAllStories() async -> [Story]
    func createStory(title: String) async -> Story
    func updateStory(_ story: Story) async
    @discardableResult
    func deleteStory(id: UUID) async -> Bool
    func loadChapters(storyID: UUID) async -> [Chapter]
    func createChapter(storyID: UUID, title: String) async -> Chapter?
    func updateChapter(_ chapter: Chapter) async
    @discardableResult
    func deleteChapter(id: UUID, storyID: UUID) async -> Bool
    func loadCharacters(storyID: UUID) async -> [Character]
    func createCharacter(storyID: UUID, name: String) async -> Character?
    func updateCharacter(_ character: Character) async
    func deleteCharacter(id: UUID, storyID: UUID) async
    func importMarkdownAsChapter(storyID: UUID, title: String, content: String) async -> Chapter?
    func exportStoryAsMarkdown(storyID: UUID) async -> String?
}

extension StoryStore: StoryWriting {}