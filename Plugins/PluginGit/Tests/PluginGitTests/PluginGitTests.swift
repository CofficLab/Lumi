import Testing
@testable import PluginGit

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func validatePathRequiresAllowedDirectoryBoundary() throws {
    let allowed = "/tmp/Lumi"

    #expect(try GitService.validatePath("/tmp/Lumi", allowedDirectories: [allowed]) == "/tmp/Lumi")
    #expect(try GitService.validatePath("/tmp/Lumi/Repo", allowedDirectories: [allowed]) == "/tmp/Lumi/Repo")
    #expect(throws: GitServiceError.self) {
        try GitService.validatePath("/tmp/Lumi-Other/Repo", allowedDirectories: [allowed])
    }
}
