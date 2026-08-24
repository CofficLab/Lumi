import Testing

@testable import StoryWriterPlugin

@MainActor
@Test func v2PluginPreservesWorkspaceAndToolCatalog() async throws {
    let plugin = StoryWriterSuperPlugin()
    let expectedTools: Set<String> = [
        "list_stories", "get_story", "create_story", "update_story", "delete_story",
        "list_chapters", "get_chapter", "create_chapter", "update_chapter", "delete_chapter",
        "import_markdown_as_chapter", "export_story_as_markdown",
    ]

    #expect(plugin.id == "com.coffic.lumi.plugin.story-writer")
    #expect(Set(StoryWriterV2Tool.all.map(\.name)) == expectedTools)
}
