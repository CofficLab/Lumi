import Foundation
import LumiKernel
import SuperLogKit

// MARK: - list_chapters

/// List all chapters in a story.
public struct ListChaptersTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📑"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "list_chapters",
        displayName: "List Chapters",
        description: """
        List all chapters of a story, ordered by their creation order. Each
        entry includes the chapter id, title, status, target word count, and
        current word count. Use `get_chapter` to read the full content.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story whose chapters to list"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("story_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "List chapters" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .safe }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        try kernel.checkCancellation()

        guard let idString = arguments.string("story_id"), let id = UUID(uuidString: idString) else {
            return "Error: valid story_id is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        let chapters = await store.loadChapters(storyID: id)

        if chapters.isEmpty {
            return "No chapters in this story yet. Use `create_chapter` to add the first one."
        }

        var output = "Found \(chapters.count) chapter/chapters:\n\n"
        for (index, chapter) in chapters.enumerated() {
            let statusText: String
            switch chapter.status {
            case .draft: statusText = "draft"
            case .inProgress: statusText = "in progress"
            case .done: statusText = "done"
            }
            output += "\(index + 1). **\(chapter.title)** — \(statusText) — \(chapter.wordCount) words (id: `\(chapter.id.uuidString)`)\n"
        }
        return output
    }
}

// MARK: - get_chapter

/// Fetch the full content of a single chapter by id.
public struct GetChapterTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📄"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "get_chapter",
        displayName: "Get Chapter",
        description: """
        Fetch the full content of a single chapter (title, status, target word
        count, and the markdown body) by its id.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story that owns the chapter"),
                    "minLength": .int(1)
                ]),
                "chapter_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the chapter to fetch"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("story_id"), .string("chapter_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Get chapter" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .safe }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        try kernel.checkCancellation()

        guard let storyID = UUID(uuidString: arguments.string("story_id") ?? "") else {
            return "Error: valid story_id is required"
        }
        guard let chapterID = UUID(uuidString: arguments.string("chapter_id") ?? "") else {
            return "Error: valid chapter_id is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        guard let chapter = await store.loadChapter(id: chapterID, storyID: storyID) else {
            return "Error: chapter not found"
        }

        let statusText: String
        switch chapter.status {
        case .draft: statusText = "draft"
        case .inProgress: statusText = "in progress"
        case .done: statusText = "done"
        }

        return """
        **\(chapter.title)**
        - id: `\(chapter.id.uuidString)`
        - status: \(statusText)
        - target words: \(chapter.targetWordCount)
        - current words: \(chapter.wordCount)
        - created: \(chapter.createdAt.formatted(date: .abbreviated, time: .shortened))
        - updated: \(chapter.updatedAt.formatted(date: .abbreviated, time: .shortened))

        **Content:**
        \(chapter.content.isEmpty ? "_(empty)_" : chapter.content)
        """
    }
}

// MARK: - create_chapter

/// Create a new chapter in a story.
public struct CreateChapterTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📝"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "create_chapter",
        displayName: "Create Chapter",
        description: """
        Create a new chapter in the given story. Optionally seed it with
        initial markdown content and a target word count. The new chapter
        becomes the selected node in the rail tab.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story to add the chapter to"),
                    "minLength": .int(1)
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Title of the new chapter"),
                    "minLength": .int(1)
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("Optional initial markdown body for the chapter")
                ]),
                "target_word_count": .object([
                    "type": .string("integer"),
                    "description": .string("Optional target word count (use 0 or omit to leave unset)")
                ])
            ]),
            "required": .array([.string("story_id"), .string("title")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Create chapter" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        try kernel.checkCancellation()

        guard let storyID = UUID(uuidString: arguments.string("story_id") ?? "") else {
            return "Error: valid story_id is required"
        }
        guard let title = arguments.string("title"), !title.isEmpty else {
            return "Error: title is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        let target = arguments.int("target_word_count") ?? 0
        let content = arguments.string("content") ?? ""

        // Step 1: create with just the title.
        guard var chapter = await store.createChapter(storyID: storyID, title: title) else {
            return "Error: failed to create chapter (story may not exist)"
        }

        // Step 2: enrich with optional content / target / status.
        if !content.isEmpty {
            chapter.content = content
            chapter.status = .inProgress
        }
        if target > 0 {
            chapter.targetWordCount = target
        }
        if chapter.content != "" || chapter.targetWordCount != 0 {
            await store.updateChapter(chapter)
        }

        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)
        return "✅ Created chapter **\(chapter.title)** (id: `\(chapter.id.uuidString)`)."
    }
}

// MARK: - update_chapter

/// Update a chapter's title, content, status, or target word count.
public struct UpdateChapterTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "✏️"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "update_chapter",
        displayName: "Update Chapter",
        description: """
        Update a chapter's title, content, status, and/or target word count.
        Provide whichever fields you want to change; omitted fields are left
        untouched.

        The `status` field accepts one of: `draft`, `in_progress`, `done`.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story that owns the chapter"),
                    "minLength": .int(1)
                ]),
                "chapter_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the chapter to update"),
                    "minLength": .int(1)
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("New title (optional)")
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("New markdown body (optional). WARNING: this replaces the full content.")
                ]),
                "status": .object([
                    "type": .string("string"),
                    "description": .string("New status: 'draft', 'in_progress', or 'done' (optional)"),
                    "enum": .array([.string("draft"), .string("in_progress"), .string("done")])
                ]),
                "target_word_count": .object([
                    "type": .string("integer"),
                    "description": .string("New target word count (optional)")
                ])
            ]),
            "required": .array([.string("story_id"), .string("chapter_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Update chapter" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        try kernel.checkCancellation()

        guard let storyID = UUID(uuidString: arguments.string("story_id") ?? "") else {
            return "Error: valid story_id is required"
        }
        guard let chapterID = UUID(uuidString: arguments.string("chapter_id") ?? "") else {
            return "Error: valid chapter_id is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        guard var chapter = await store.loadChapter(id: chapterID, storyID: storyID) else {
            return "Error: chapter not found"
        }

        if let newTitle = arguments.string("title"), !newTitle.isEmpty {
            chapter.title = newTitle
        }
        if let newContent = arguments.string("content") {
            chapter.content = newContent
        }
        if let statusRaw = arguments.string("status") {
            switch statusRaw {
            case "draft": chapter.status = .draft
            case "in_progress", "inProgress": chapter.status = .inProgress
            case "done": chapter.status = .done
            default:
                return "Error: invalid status '\(statusRaw)'. Use 'draft', 'in_progress', or 'done'."
            }
        }
        if let target = arguments.int("target_word_count") {
            chapter.targetWordCount = target
        }

        await store.updateChapter(chapter)
        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)
        return "✅ Updated chapter **\(chapter.title)** (\(chapter.wordCount) words)."
    }
}

// MARK: - delete_chapter

/// Delete a chapter from a story.
public struct DeleteChapterTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🗑️"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "delete_chapter",
        displayName: "Delete Chapter",
        description: """
        Permanently delete a chapter from a story. This action cannot be
        undone.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story that owns the chapter"),
                    "minLength": .int(1)
                ]),
                "chapter_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the chapter to delete"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("story_id"), .string("chapter_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Delete chapter" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .medium }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        try kernel.checkCancellation()

        guard let storyID = UUID(uuidString: arguments.string("story_id") ?? "") else {
            return "Error: valid story_id is required"
        }
        guard let chapterID = UUID(uuidString: arguments.string("chapter_id") ?? "") else {
            return "Error: valid chapter_id is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        let chapter = await store.loadChapter(id: chapterID, storyID: storyID)
        await store.deleteChapter(id: chapterID, storyID: storyID)

        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)
        if let title = chapter?.title {
            return "🗑️ Deleted chapter **\(title)**."
        }
        return "🗑️ Deleted chapter \(chapterID.uuidString)."
    }
}