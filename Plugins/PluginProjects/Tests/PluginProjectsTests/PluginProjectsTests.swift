import Testing
@testable import PluginProjects

@Test func branchDisplayNameIgnoresMissingAndBlankValues() async throws {
    #expect(GitBranchCache.displayName(for: nil) == nil)
    #expect(GitBranchCache.displayName(for: "") == nil)
    #expect(GitBranchCache.displayName(for: " \n\t ") == nil)
    #expect(GitBranchCache.displayName(for: "  main\n") == "main")
}
