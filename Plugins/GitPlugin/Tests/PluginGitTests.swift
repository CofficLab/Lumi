import Testing
@testable import GitPlugin

@Test func packageLoads() async throws {
    #expect(GitPlugin.id == "GitPlugin")
    #expect(GitPlugin.displayName.isEmpty == false)
    #expect(GitPlugin.iconName == "arrow.triangle.branch")
    #expect(GitPlugin.order == 11)
    #expect(GitPlugin.category == .development)
}

@Test func gitLogToolNormalizesCount() throws {
    #expect(GitLogTool.normalizedCount(nil) == 10)
    #expect(GitLogTool.normalizedCount(-5) == 1)
    #expect(GitLogTool.normalizedCount(0) == 1)
    #expect(GitLogTool.normalizedCount(12) == 12)
    #expect(GitLogTool.normalizedCount(12.0) == 12)
    #expect(GitLogTool.normalizedCount("12") == 12)
    #expect(GitLogTool.normalizedCount(500) == 50)
    #expect(GitLogTool.normalizedCount("not-a-number") == 10)

    let schema = GitLogTool().inputSchema(for: .english)
    let properties = try #require(schema["properties"] as? [String: [String: Any]])
    #expect(properties["count"]?["type"] as? String == "integer")
    #expect(properties["count"]?["minimum"] as? Int == 1)
    #expect(properties["count"]?["maximum"] as? Int == 50)
}

@Test func validatePathRequiresAllowedDirectoryBoundary() throws {
    let allowed = "/tmp/Lumi"

    #expect(try GitService.validatePath("/tmp/Lumi", allowedDirectories: [allowed]) == "/tmp/Lumi")
    #expect(try GitService.validatePath("/tmp/Lumi/Repo", allowedDirectories: [allowed]) == "/tmp/Lumi/Repo")
    #expect(throws: GitServiceError.self) {
        try GitService.validatePath("/tmp/Lumi-Other/Repo", allowedDirectories: [allowed])
    }
}

@Test func validateBranchNameAcceptsCommonGitNames() throws {
    try GitBranchService.validateBranchName("feature/editor-refresh")
    try GitBranchService.validateBranchName("bugfix/issue-123")
    try GitBranchService.validateBranchName("release_2026.06")
}

@Test func validateBranchNameRejectsInvalidGitNames() {
    let invalidNames = [
        "",
        " feature",
        "feature ",
        "-feature",
        "/feature",
        "feature/",
        "feature//editor",
        "feature..editor",
        "feature@{editor",
        "feature.lock",
        "feature/.hidden",
        "feature/editor.lock",
        "feature editor",
        "feature:editor",
        "feature?editor",
        "feature*editor",
        "feature[editor",
        #"feature\editor"#,
        "@"
    ]

    for name in invalidNames {
        #expect(throws: GitError.self) {
            try GitBranchService.validateBranchName(name)
        }
    }
}

@Test func remoteDisplayNamePreservesSpacesInLocalRemotePath() {
    let remote = GitCommitDetailService.parseRemoteDisplayName(from: "origin\t/tmp/My Repo.git (fetch)\norigin\t/tmp/My Repo.git (push)")

    #expect(remote == "/tmp/My Repo")
}

@Test func remoteDisplayNameKeepsSshRepositoryPath() {
    let remote = GitCommitDetailService.parseRemoteDisplayName(from: "origin\tgit@github.com:CofficLab/Lumi.git (fetch)")

    #expect(remote == "CofficLab/Lumi")
}
