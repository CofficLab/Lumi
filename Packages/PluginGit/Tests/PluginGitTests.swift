import Foundation
import SwiftUI
import Testing
import EditorContracts
import KernelCore
import KitAgentTool
import ProviderToolManager
@testable import GitPlugin

@MainActor
@Test func sourceControlPluginRegistersEditorContract() throws {
    let kernel = KernelCoreContainer()
    let plugin = GitSourceControlSuperPlugin()
    try plugin.onBoot(kernel: kernel)
    #expect(kernel.resolveProvider((any SourceControlProviding).self) is GitSourceControlAdapter)
}

@MainActor
@Test func v2PluginRegistersAllLegacyGitToolNames() throws {
    let kernel = KernelCoreContainer()
    let toolManager = DefaultToolManagerProviding()
    try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

    try GitSourceControlSuperPlugin().onBoot(kernel: kernel)

    #expect(toolManager.allTools().map(\.name) == GitV2ToolNames.all)
    #expect(toolManager.tool(named: "git_status")?.permissionRiskLevel(arguments: [:]) == .low)
    #expect(toolManager.tool(named: "git_commit")?.permissionRiskLevel(arguments: [:]) == .medium)
    #expect(toolManager.tool(named: "git_branch")?.permissionRiskLevel(arguments: ["action": ToolArgument("checkout")]) == .medium)
}

@MainActor
@Test func gitLogToolNormalizesCount() throws {
    #expect(GitLogTool.normalizedCount(nil) == 10)
    #expect(GitLogTool.normalizedCount(-5) == 1)
    #expect(GitLogTool.normalizedCount(0) == 1)
    #expect(GitLogTool.normalizedCount(12) == 12)
    #expect(GitLogTool.normalizedCount(12.0) == 12)
    #expect(GitLogTool.normalizedCount("12") == 12)
    #expect(GitLogTool.normalizedCount(500) == 50)
    #expect(GitLogTool.normalizedCount("not-a-number") == 10)

    let schema = GitLogTool().inputSchema
    guard let properties = schema["properties"] as? [String: Any],
          let countProps = properties["count"] as? [String: Any] else {
        Issue.record("schema should declare count property")
        return
    }
    if let type = countProps["type"] as? String {
        #expect(type == "integer")
    } else {
        Issue.record("count type missing")
    }
    if let minimum = countProps["minimum"] as? Int {
        #expect(minimum == 1)
    } else {
        Issue.record("count minimum missing")
    }
    if let maximum = countProps["maximum"] as? Int {
        #expect(maximum == 50)
    } else {
        Issue.record("count maximum missing")
    }
}

@MainActor
@Test func validatePathRequiresAllowedDirectoryBoundary() throws {
    let allowed = "/tmp/Lumi"

    #expect(try GitService.validatePath("/tmp/Lumi", allowedDirectories: [allowed]) == "/tmp/Lumi")
    #expect(try GitService.validatePath("/tmp/Lumi/Repo", allowedDirectories: [allowed]) == "/tmp/Lumi/Repo")
    #expect(throws: GitServiceError.self) {
        try GitService.validatePath("/tmp/Lumi-Other/Repo", allowedDirectories: [allowed])
    }
}

@MainActor
@Test func validatePathUsesCurrentProjectPathWhenToolPathIsBlank() throws {
    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("lumi-git-path-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.removeItem(at: projectURL)
    }

    let resolved = try GitService.validatePath(
        "",
        currentProjectPath: projectURL.path,
        allowedDirectories: [projectURL.path]
    )

    #expect(resolved == (try GitService.validatePath(projectURL.path, allowedDirectories: [])))
}

@MainActor
@Test func gitServiceFindsRepositoryRootForFilePath() throws {
    let filePath = URL(fileURLWithPath: #filePath).path
    let root = try GitService.repositoryRoot(containing: filePath)
    let relative = GitService.relativePath(filePath, fromRepositoryRoot: root)

    #expect(relative == "Packages/PluginGit/Tests/PluginGitTests.swift")
}

@MainActor
@Test func validateBranchNameAcceptsCommonGitNames() throws {
    try GitBranchService.validateBranchName("feature/editor-refresh")
    try GitBranchService.validateBranchName("bugfix/issue-123")
    try GitBranchService.validateBranchName("release_2026.06")
}

@MainActor
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

@MainActor
@Test func remoteDisplayNamePreservesSpacesInLocalRemotePath() {
    let remote = GitCommitDetailService.parseRemoteDisplayName(from: "origin\t/tmp/My Repo.git (fetch)\norigin\t/tmp/My Repo.git (push)")

    #expect(remote == "/tmp/My Repo")
}

@MainActor
@Test func remoteDisplayNameKeepsSshRepositoryPath() {
    let remote = GitCommitDetailService.parseRemoteDisplayName(from: "origin\tgit@github.com:CofficLab/Lumi.git (fetch)")

    #expect(remote == "CofficLab/Lumi")
}
