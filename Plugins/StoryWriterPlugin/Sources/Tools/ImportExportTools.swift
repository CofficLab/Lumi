import Foundation
import LumiKernel
import SuperLogKit

// MARK: - import_markdown_as_chapter

/// Create a new chapter from a Markdown string.
public struct ImportMarkdownAsChapterTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📥"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "import_markdown_as_chapter",
        displayName: "Import Markdown As Chapter",
        description: """
        Create a new chapter in the given story from a Markdown string. Use
        this to import text the user has already written (or generated)
        elsewhere into the story library.
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story to import into"),
                    "minLength": .int(1)
                ]),
                "title": .object([
                    "type": .string("string"),
                    "description": .string("Title of the new chapter"),
                    "minLength": .int(1)
                ]),
                "content": .object([
                    "type": .string("string"),
                    "description": .string("Markdown body for the new chapter"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("story_id"), .string("title"), .string("content")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Import markdown as chapter" }
    public func riskLevel(arguments: [String: LumiJSONValue], kernel: LumiKernel) -> LumiCommandRiskLevel { .low }

    public func execute(arguments: [String: LumiJSONValue], kernel: LumiKernel) async throws -> String {
        try kernel.checkCancellation()

        guard let storyID = UUID(uuidString: arguments.string("story_id") ?? "") else {
            return "Error: valid story_id is required"
        }
        guard let title = arguments.string("title"), !title.isEmpty else {
            return "Error: title is required"
        }
        guard let content = arguments.string("content"), !content.isEmpty else {
            return "Error: content is required"
        }

        guard let directory = await StoryWriterStorage.directory(kernel: kernel) else {
            return "Error: storage service is not available"
        }

        let store = StoryStore(pluginDirectory: directory)
        guard let chapter = await store.importMarkdownAsChapter(storyID: storyID, title: title, content: content) else {
            return "Error: failed to import chapter (story may not exist)"
        }

        NotificationCenter.default.post(name: .storyWriterDidChange, object: nil)
        return "✅ Imported chapter **\(chapter.title)** (id: `\(chapter.id.uuidString)`, \(chapter.wordCount) words)."
    }
}

// MARK: - export_story_as_markdown

/// Export a whole story (synopsis + all chapters + characters) as Markdown.
public struct ExportStoryAsMarkdownTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "📤"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "export_story_as_markdown",
        displayName: "Export Story As Markdown",
        description: """
        Export an entire story as a Markdown document. The output includes the
        story title, synopsis, every chapter (with its full content), and a
        characters section. Use this when the user wants the whole story as
        a single text blob (for backup, sharing, or further processing).
        """
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "story_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID of the story to export"),
                    "minLength": .int(1)
                ])
            ]),
            "required": .array([.string("story_id")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "Export story as markdown" }
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
        guard let markdown = await store.exportStoryAsMarkdown(storyID: id) else {
            return "Error: story not found"
        }

        let chapters = await store.loadChapters(storyID: id)
        return "Exported story as Markdown (\(chapters.count) chapters, \(markdown.count) characters):\n\n```\n\(markdown)\n```"
    }
}