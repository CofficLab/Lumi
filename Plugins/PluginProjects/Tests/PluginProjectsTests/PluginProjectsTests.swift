import Testing
@testable import PluginProjects

@Test func branchDisplayNameIgnoresMissingAndBlankValues() async throws {
    #expect(GitBranchCache.displayName(for: nil) == nil)
    #expect(GitBranchCache.displayName(for: "") == nil)
    #expect(GitBranchCache.displayName(for: " \n\t ") == nil)
    #expect(GitBranchCache.displayName(for: "  main\n") == "main")
}

@Test func addProjectToolTrimsCopiedPathWhitespace() {
    #expect(AddProjectTool.normalizedPath(from: " \n/Users/example/Project\t") == "/Users/example/Project")
}

@Test func addProjectToolRejectsBlankCopiedPath() {
    #expect(AddProjectTool.normalizedPath(from: " \n\t ") == nil)
}
