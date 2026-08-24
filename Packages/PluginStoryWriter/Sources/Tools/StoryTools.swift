import Foundation
import KernelLumi
import SuperLogKit

// MARK: - list_stories

/// List all stories in the user's story library.
public struct ListStoriesTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📚"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "list_stories",
        displayName: "List Stories",
        description: """
        List all stories in the user's story library.

        Returns a summary (id, title, last updated timestamp) for every story,
        ordered by most recently updated first. Use `get_story` to read the
        full metadata of a particular story.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "List stories" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .safe }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        let stories = await store.loadAllStories()

        if stories.isEmpty {
            return "No stories found. Use `create_story` to create the first one."
        }

        var output = "Found \(stories.count) story/stories:\n\n"
        for story in stories {
            let updated = story.updatedAt.formatted(date: .abbreviated, time: .shortened)
            output += "- **\(story.title)** (id: `\(story.id.uuidString)`, updated: \(updated))\n"
        }
        return output
    }
}

// MARK: - get_story

/// Fetch the full metadata of a single story by id (or title).
public struct GetStoryTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📖"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "get_story",
        displayName: "Get Story",
        description: """
        Fetch the full metadata of a single story by its id or by its exact
        title. Returns the story id, title, synopsis, created/updated
        timestamps, and the number of chapters and characters.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story to fetch")
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Exact title of the story to fetch (used as fallback when story_id is not provided)")
                ])
            ])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Get story" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .safe }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)

        let story: Story?
        if let idString = arguments.string("story_id"), let id = UUID(uuidString: idString) {
            story = await store.loadStory(id: id)
        } else if let title = arguments.string("title") {
            let all = await store.loadAllStories()
            story = all.first { $0.title == title }
        } else {
            return "Error: provide either `story_id` or `title`"
        }

        guard let story else {
            return "Error: story not found"
        }

        let chapters = await store.loadChapters(storyID: story.id)
        let characters = await store.loadCharacters(storyID: story.id)
        let wordCount = chapters.reduce(0) { $0 + $1.wordCount }

        return """
        **\(story.title)**
        - id: `\(story.id.uuidString)`
        - created: \(story.createdAt.formatted(date: .abbreviated, time: .shortened))
        - updated: \(story.updatedAt.formatted(date: .abbreviated, time: .shortened))
        - chapters: \(chapters.count) (\(wordCount) words)
        - characters: \(characters.count)

        **Synopsis:**
        \(story.synopsis.isEmpty ? "_(empty)_" : story.synopsis)
        """
    }
}

// MARK: - create_story

/// Create a new story with just a title (synopsis empty by default).
public struct CreateStoryTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "✨"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "create_story",
        displayName: "Create Story",
        description: """
        Create a new story with a title and optional synopsis. The new story
        becomes the active story in the rail tab. Use `update_story` later to
        refine the synopsis.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Title of the new story"),
                    "minLength": .int(1)
                ]),
                "synopsis": .object([
                    "type": .string("string"),
                    "description": .string("Optional short synopsis for the new story")
                ])
            ]),
            "required": .array([.string("title")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Create story" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let title = arguments.string("title"), !title.isEmpty else {
            return "Error: title is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        let story = await store.createStory(title: title)

        if let synopsis = arguments.string("synopsis"), !synopsis.isEmpty {
            var updated = story
            updated.synopsis = synopsis
            await store.updateStory(updated)
        }

        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)

        return """
        ✅ Created story **\(story.title)** (id: `\(story.id.uuidString)`).
        Use `create_chapter` to start writing.
        """
    }
}

// MARK: - update_story

/// Update a story's title and/or synopsis.
public struct UpdateStoryTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "update_story",
        displayName: "Update Story",
        description: """
        Update a story's title and/or synopsis. Provide whichever field you
        want to change; omitted fields are left untouched.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story to update"),
                    "minLength": .int(1)
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("New title (optional)")
                ]),
                "synopsis": .object([
                    "type": .string("string"),
                    "description": .string("New synopsis (optional)")
                ])
            ]),
            "required": .array([.string("story_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Update story" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let idString = arguments.string("story_id"), let id = UUID(uuidString: idString) else {
            return "Error: valid story_id is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        guard var story = await store.loadStory(id: id) else {
            return "Error: story not found"
        }

        if let newTitle = arguments.string("title"), !newTitle.isEmpty {
            story.title = newTitle
        }
        if let newSynopsis = arguments.string("synopsis") {
            story.synopsis = newSynopsis
        }
        await store.updateStory(story)

        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)
        return "✅ Updated story **\(story.title)**."
    }
}

// MARK: - delete_story

/// Delete a story and all its chapters and characters (irreversible).
public struct DeleteStoryTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🗑️"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "delete_story",
        displayName: "Delete Story",
        description: """
        Permanently delete a story together with all its chapters and
        characters. This action cannot be undone.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story to delete"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("story_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Delete story" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel { .medium }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()

        guard let idString = arguments.string("story_id"), let id = UUID(uuidString: idString) else {
            return "Error: valid story_id is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        let story = await store.loadStory(id: id)
        await store.deleteStory(id: id)

        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)
        if let title = story?.title {
            return "🗑️ Deleted story **\(title)**."
        }
        return "🗑️ Deleted story \(id.uuidString)."
    }
}