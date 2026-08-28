import Foundation
import os
import KitSuperLog

/// Persistent storage for story writer data.
///
/// File layout under `pluginDirectory`:
/// ```
/// stories/
///   {storyID}/
///     story.json
///     chapters/
///       {chapterID}.json
///     characters/
///       {characterID}.json
/// ```
public actor StoryStore: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.story-writer.store")
    public nonisolated static let emoji = "📖"
    nonisolated static let verbose = false

    private let pluginDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(pluginDirectory: URL) {
        self.pluginDirectory = pluginDirectory
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Stories

    public func loadAllStories() -> [Story] {
        let storiesDir = pluginDirectory.appendingPathComponent("stories")
        guard let storyDirs = try? FileManager.default.contentsOfDirectory(
            at: storiesDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var stories: [Story] = []
        for dir in storyDirs {
            let storyFile = dir.appendingPathComponent("story.json")
            if let data = try? Data(contentsOf: storyFile),
               let story = try? decoder.decode(Story.self, from: data) {
                stories.append(story)
            }
        }
        return stories.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func loadStory(id: UUID) -> Story? {
        let storyFile = storyDirectory(for: id).appendingPathComponent("story.json")
        guard let data = try? Data(contentsOf: storyFile) else { return nil }
        return try? decoder.decode(Story.self, from: data)
    }

    public func createStory(title: String) -> Story {
        let story = Story(title: title)
        saveStory(story)
        return story
    }

    public func updateStory(_ story: Story) {
        var updated = story
        updated.updatedAt = .now
        saveStory(updated)
    }

    public func deleteStory(id: UUID) {
        let dir = storyDirectory(for: id)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Chapters

    public func loadChapters(storyID: UUID) -> [Chapter] {
        let chaptersDir = storyDirectory(for: storyID).appendingPathComponent("chapters")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: chaptersDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var chapters: [Chapter] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let chapter = try? decoder.decode(Chapter.self, from: data) {
                chapters.append(chapter)
            }
        }
        // Preserve order by createdAt
        return chapters.sorted { $0.createdAt < $1.createdAt }
    }

    public func loadChapter(id: UUID, storyID: UUID) -> Chapter? {
        let file = chapterFile(id: id, storyID: storyID)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? decoder.decode(Chapter.self, from: data)
    }

    public func createChapter(storyID: UUID, title: String) -> Chapter? {
        guard var story = loadStory(id: storyID) else { return nil }
        let chapter = Chapter(storyID: storyID, title: title)
        saveChapter(chapter)
        story.chapterIDs.append(chapter.id)
        saveStory(story)
        return chapter
    }

    public func updateChapter(_ chapter: Chapter) {
        var updated = chapter
        updated.updatedAt = .now
        saveChapter(updated)
    }

    public func deleteChapter(id: UUID, storyID: UUID) {
        let file = chapterFile(id: id, storyID: storyID)
        try? FileManager.default.removeItem(at: file)
        if var story = loadStory(id: storyID) {
            story.chapterIDs.removeAll { $0 == id }
            saveStory(story)
        }
    }

    // MARK: - Characters

    public func loadCharacters(storyID: UUID) -> [Character] {
        let charsDir = storyDirectory(for: storyID).appendingPathComponent("characters")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: charsDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var characters: [Character] = []
        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let character = try? decoder.decode(Character.self, from: data) {
                characters.append(character)
            }
        }
        return characters.sorted { $0.createdAt < $1.createdAt }
    }

    public func loadCharacter(id: UUID, storyID: UUID) -> Character? {
        let file = characterFile(id: id, storyID: storyID)
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? decoder.decode(Character.self, from: data)
    }

    public func createCharacter(storyID: UUID, name: String) -> Character? {
        guard var story = loadStory(id: storyID) else { return nil }
        let character = Character(storyID: storyID, name: name)
        saveCharacter(character)
        story.characterIDs.append(character.id)
        saveStory(story)
        return character
    }

    public func updateCharacter(_ character: Character) {
        var updated = character
        updated.updatedAt = .now
        saveCharacter(updated)
    }

    public func deleteCharacter(id: UUID, storyID: UUID) {
        let file = characterFile(id: id, storyID: storyID)
        try? FileManager.default.removeItem(at: file)
        if var story = loadStory(id: storyID) {
            story.characterIDs.removeAll { $0 == id }
            saveStory(story)
        }
    }

    // MARK: - Import / Export

    public func importMarkdownAsChapter(storyID: UUID, title: String, content: String) -> Chapter? {
        guard var story = loadStory(id: storyID) else { return nil }
        let chapter = Chapter(storyID: storyID, title: title, content: content)
        saveChapter(chapter)
        story.chapterIDs.append(chapter.id)
        saveStory(story)
        return chapter
    }

    public func exportStoryAsMarkdown(storyID: UUID) -> String? {
        guard let story = loadStory(id: storyID) else { return nil }
        var markdown = "# \(story.title)\n\n"
        if !story.synopsis.isEmpty {
            markdown += "## Synopsis\n\n\(story.synopsis)\n\n"
        }

        let chapters = loadChapters(storyID: storyID)
        for chapter in chapters {
            markdown += "## \(chapter.title)\n\n"
            markdown += chapter.content
            markdown += "\n\n---\n\n"
        }

        let characters = loadCharacters(storyID: storyID)
        if !characters.isEmpty {
            markdown += "## Characters\n\n"
            for char in characters {
                markdown += "### \(char.name)\n"
                if !char.role.isEmpty { markdown += "**Role:** \(char.role)\n" }
                if !char.personality.isEmpty { markdown += "**Personality:** \(char.personality)\n" }
                if !char.notes.isEmpty { markdown += "**Notes:** \(char.notes)\n" }
                markdown += "\n"
            }
        }
        return markdown
    }

    // MARK: - Private Helpers

    private func storyDirectory(for storyID: UUID) -> URL {
        pluginDirectory
            .appendingPathComponent("stories")
            .appendingPathComponent(storyID.uuidString)
    }

    private func chapterFile(id: UUID, storyID: UUID) -> URL {
        storyDirectory(for: storyID)
            .appendingPathComponent("chapters")
            .appendingPathComponent("\(id.uuidString).json")
    }

    private func characterFile(id: UUID, storyID: UUID) -> URL {
        storyDirectory(for: storyID)
            .appendingPathComponent("characters")
            .appendingPathComponent("\(id.uuidString).json")
    }

    private func saveStory(_ story: Story) {
        let dir = storyDirectory(for: story.id)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("story.json")
        if let data = try? encoder.encode(story) {
            try? data.write(to: file, options: [.atomic])
        }
    }

    private func saveChapter(_ chapter: Chapter) {
        let dir = storyDirectory(for: chapter.storyID).appendingPathComponent("chapters")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(chapter.id.uuidString).json")
        if let data = try? encoder.encode(chapter) {
            try? data.write(to: file, options: [.atomic])
        }
    }

    private func saveCharacter(_ character: Character) {
        let dir = storyDirectory(for: character.storyID).appendingPathComponent("characters")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(character.id.uuidString).json")
        if let data = try? encoder.encode(character) {
            try? data.write(to: file, options: [.atomic])
        }
    }
}
