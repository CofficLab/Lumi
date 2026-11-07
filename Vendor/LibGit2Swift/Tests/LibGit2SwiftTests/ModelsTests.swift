import Foundation
@testable import LibGit2Swift
import XCTest

/// 数据模型测试
final class ModelsTests: XCTestCase {

    // MARK: - GitBranch Tests

    func testGitBranchModel() {
        let branch = GitBranch(
            id: "branch-1",
            name: "feature",
            isCurrent: true,
            upstream: "origin/feature",
            latestCommitHash: "abc123",
            latestCommitMessage: "Latest commit"
        )

        XCTAssertEqual(branch.id, "branch-1")
        XCTAssertEqual(branch.name, "feature")
        XCTAssertTrue(branch.isCurrent)
        XCTAssertEqual(branch.upstream, "origin/feature")
        XCTAssertEqual(branch.latestCommitHash, "abc123")
        XCTAssertEqual(branch.latestCommitMessage, "Latest commit")
    }

    func testGitBranchHashable() {
        let branch1 = GitBranch(
            id: "branch-1",
            name: "main",
            isCurrent: true,
            upstream: nil,
            latestCommitHash: "hash1",
            latestCommitMessage: "msg1"
        )

        let branch2 = GitBranch(
            id: "branch-1",
            name: "main",
            isCurrent: true,
            upstream: nil,
            latestCommitHash: "hash1",
            latestCommitMessage: "msg1"
        )

        let branch3 = GitBranch(
            id: "branch-2",
            name: "feature",
            isCurrent: false,
            upstream: nil,
            latestCommitHash: "hash2",
            latestCommitMessage: "msg2"
        )

        XCTAssertEqual(branch1, branch2)
        XCTAssertNotEqual(branch1, branch3)
    }

    func testGitBranchCodable() throws {
        let branch = GitBranch(
            id: "test",
            name: "develop",
            isCurrent: false,
            upstream: "origin/develop",
            latestCommitHash: "def456",
            latestCommitMessage: "Test commit"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(branch)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GitBranch.self, from: data)

        XCTAssertEqual(decoded.id, branch.id)
        XCTAssertEqual(decoded.name, branch.name)
        XCTAssertEqual(decoded.isCurrent, branch.isCurrent)
        XCTAssertEqual(decoded.upstream, branch.upstream)
    }

    // MARK: - GitCommit Tests

    func testGitCommitModel() {
        let commit = GitCommit(
            id: "commit-1",
            hash: "abc123def456",
            author: "John Doe",
            email: "john@example.com",
            date: Date(),
            message: "Test commit",
            body: "",
            refs: ["main"],
            tags: ["v1.0"],
            parentHashes: ["parent1"]
        )

        XCTAssertEqual(commit.id, "commit-1")
        XCTAssertEqual(commit.hash, "abc123def456")
        XCTAssertEqual(commit.author, "John Doe")
        XCTAssertEqual(commit.email, "john@example.com")
        XCTAssertEqual(commit.message, "Test commit")
        XCTAssertEqual(commit.refs, ["main"])
        XCTAssertEqual(commit.tags, ["v1.0"])
        XCTAssertEqual(commit.parentHashes, ["parent1"])
    }

    func testGitCommitIsInitialCommit() {
        let initialCommit = GitCommit(
            id: "initial",
            hash: "hash1",
            author: "Author",
            email: "email@test.com",
            date: Date(),
            message: "Initial",
            body: "",
            refs: [],
            tags: [],
            parentHashes: [] // Empty parent hashes
        )

        let regularCommit = GitCommit(
            id: "regular",
            hash: "hash2",
            author: "Author",
            email: "email@test.com",
            date: Date(),
            message: "Regular",
            body: "",
            refs: [],
            tags: [],
            parentHashes: ["hash1"]
        )

        XCTAssertTrue(initialCommit.isInitialCommit)
        XCTAssertFalse(regularCommit.isInitialCommit)
    }

    func testGitCommitIsMergeCommit() {
        let mergeCommit = GitCommit(
            id: "merge",
            hash: "mergehash",
            author: "Author",
            email: "email@test.com",
            date: Date(),
            message: "Merge",
            body: "",
            refs: [],
            tags: [],
            parentHashes: ["parent1", "parent2"] // Two parents
        )

        let regularCommit = GitCommit(
            id: "regular",
            hash: "regularhash",
            author: "Author",
            email: "email@test.com",
            date: Date(),
            message: "Regular",
            body: "",
            refs: [],
            tags: [],
            parentHashes: ["parent1"]
        )

        XCTAssertTrue(mergeCommit.isMergeCommit)
        XCTAssertFalse(regularCommit.isMergeCommit)
    }

    func testGitCommitCoAuthors() {
        let commitWithCoAuthors = GitCommit(
            id: "test",
            hash: "hash",
            author: "John Doe",
            email: "john@example.com",
            date: Date(),
            message: "Test commit\n\nCo-Authored-By: Jane Smith <jane@example.com>",
            body: "",
            refs: [],
            tags: [],
            parentHashes: []
        )

        let coAuthors = commitWithCoAuthors.coAuthors
        XCTAssertEqual(coAuthors.count, 1)
        XCTAssertEqual(coAuthors[0], "Jane Smith")
    }

    func testGitCommitCoAuthorsFromBody() {
        let commitWithCoAuthors = GitCommit(
            id: "test",
            hash: "hash",
            author: "John Doe",
            email: "john@example.com",
            date: Date(),
            message: "Test commit",
            body: "Co-Authored-By: Alice <alice@example.com>\nCo-Authored-By: Bob <bob@example.com>",
            refs: [],
            tags: [],
            parentHashes: []
        )

        let coAuthors = commitWithCoAuthors.coAuthors
        XCTAssertEqual(coAuthors.count, 2)
        XCTAssertTrue(coAuthors.contains("Alice"))
        XCTAssertTrue(coAuthors.contains("Bob"))
    }

    func testGitCommitAllAuthors() {
        let commit = GitCommit(
            id: "test",
            hash: "hash",
            author: "John Doe",
            email: "john@example.com",
            date: Date(),
            message: "Test\n\nCo-Authored-By: Jane Smith <jane@example.com>",
            body: "",
            refs: [],
            tags: [],
            parentHashes: []
        )

        XCTAssertEqual(commit.allAuthors, "John Doe + Jane Smith")
    }

    func testGitCommitCodable() throws {
        let commit = GitCommit(
            id: "test",
            hash: "hash123",
            author: "Test Author",
            email: "test@test.com",
            date: Date(),
            message: "Test message",
            body: "Test body",
            refs: ["main"],
            tags: ["v1.0"],
            parentHashes: ["parent1"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(commit)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GitCommit.self, from: data)

        XCTAssertEqual(decoded.id, commit.id)
        XCTAssertEqual(decoded.hash, commit.hash)
        XCTAssertEqual(decoded.author, commit.author)
        XCTAssertEqual(decoded.parentHashes, commit.parentHashes)
    }

    // MARK: - GitDiffFile Tests

    func testGitDiffFileModel() {
        let diffFile = GitDiffFile(
            id: "diff-1",
            file: "test.txt",
            changeType: "modified",
            diff: "--- a/test.txt\n+++ b/test.txt\n@@ -1 +1 @@",
            isBinary: false
        )

        XCTAssertEqual(diffFile.id, "diff-1")
        XCTAssertEqual(diffFile.file, "test.txt")
        XCTAssertEqual(diffFile.changeType, "modified")
        XCTAssertFalse(diffFile.isBinary)
    }

    func testGitDiffFileIsBinary() {
        let binaryFile = GitDiffFile(
            id: "binary",
            file: "image.png",
            changeType: "added",
            diff: "",
            isBinary: true
        )

        let textFile = GitDiffFile(
            id: "text",
            file: "readme.md",
            changeType: "modified",
            diff: "diff content",
            isBinary: false
        )

        XCTAssertTrue(binaryFile.isBinary)
        XCTAssertFalse(textFile.isBinary)
    }

    func testGitDiffFileIsImage() {
        let imageFile = GitDiffFile(
            id: "img",
            file: "photo.jpg",
            changeType: "modified",
            diff: "",
            isBinary: true
        )

        let textFile = GitDiffFile(
            id: "txt",
            file: "document.txt",
            changeType: "modified",
            diff: "diff",
            isBinary: false
        )

        XCTAssertTrue(imageFile.isImage)
        XCTAssertFalse(textFile.isImage)
    }

    func testGitDiffFileIsBinaryByExtension() {
        XCTAssertTrue(GitDiffFile.isBinaryByExtension("image.png"))
        XCTAssertTrue(GitDiffFile.isBinaryByExtension("font.ttf"))
        XCTAssertTrue(GitDiffFile.isBinaryByExtension("archive.zip"))
        XCTAssertTrue(GitDiffFile.isBinaryByExtension("data.pdf"))

        XCTAssertFalse(GitDiffFile.isBinaryByExtension("source.swift"))
        XCTAssertFalse(GitDiffFile.isBinaryByExtension("readme.md"))
        XCTAssertFalse(GitDiffFile.isBinaryByExtension("config.json"))
    }

    func testGitDiffFileExtensions() {
        XCTAssertTrue(GitDiffFile.imageExtensions.contains("png"))
        XCTAssertTrue(GitDiffFile.imageExtensions.contains("jpg"))
        XCTAssertTrue(GitDiffFile.imageExtensions.contains("gif"))

        XCTAssertTrue(GitDiffFile.binaryExtensions.contains("pdf"))
        XCTAssertTrue(GitDiffFile.binaryExtensions.contains("zip"))
        XCTAssertTrue(GitDiffFile.binaryExtensions.contains("ttf"))
    }

    func testGitDiffFileHashable() {
        let diff1 = GitDiffFile(
            id: "diff-1",
            file: "file.txt",
            changeType: "M",
            diff: "diff1",
            isBinary: false
        )

        let diff2 = GitDiffFile(
            id: "diff-1",
            file: "file.txt",
            changeType: "M",
            diff: "diff1",
            isBinary: false
        )

        let diff3 = GitDiffFile(
            id: "diff-2",
            file: "other.txt",
            changeType: "A",
            diff: "diff2",
            isBinary: false
        )

        XCTAssertEqual(diff1, diff2)
        XCTAssertNotEqual(diff1, diff3)
    }

    // MARK: - GitRemote Tests

    func testGitRemoteModel() {
        let remote = GitRemote(
            id: "remote-1",
            name: "origin",
            url: "https://github.com/test/repo.git",
            fetchURL: "https://github.com/test/repo.git",
            pushURL: "https://github.com/test/repo.git",
            isDefault: true
        )

        XCTAssertEqual(remote.id, "remote-1")
        XCTAssertEqual(remote.name, "origin")
        XCTAssertEqual(remote.url, "https://github.com/test/repo.git")
        XCTAssertTrue(remote.isDefault)
    }

    func testGitRemoteCodable() throws {
        let remote = GitRemote(
            id: "test",
            name: "upstream",
            url: "https://github.com/upstream/repo.git",
            fetchURL: nil,
            pushURL: nil,
            isDefault: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(remote)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GitRemote.self, from: data)

        XCTAssertEqual(decoded.id, remote.id)
        XCTAssertEqual(decoded.name, remote.name)
        XCTAssertEqual(decoded.url, remote.url)
        XCTAssertNil(decoded.fetchURL)
        XCTAssertNil(decoded.pushURL)
    }

    // MARK: - GitTag Tests

    func testGitTagModel() {
        let tag = GitTag(
            id: "tag-1",
            name: "v1.0.0",
            commitHash: "abc123def456"
        )

        XCTAssertEqual(tag.id, "tag-1")
        XCTAssertEqual(tag.name, "v1.0.0")
        XCTAssertEqual(tag.commitHash, "abc123def456")
    }

    func testGitTagHashable() {
        let tag1 = GitTag(
            id: "tag-1",
            name: "v1.0",
            commitHash: "hash1"
        )

        let tag2 = GitTag(
            id: "tag-1",
            name: "v1.0",
            commitHash: "hash1"
        )

        let tag3 = GitTag(
            id: "tag-2",
            name: "v2.0",
            commitHash: "hash2"
        )

        XCTAssertEqual(tag1, tag2)
        XCTAssertNotEqual(tag1, tag3)
    }

    func testGitTagCodable() throws {
        let tag = GitTag(
            id: "test-tag",
            name: "release-1.0",
            commitHash: "commit-hash-123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(tag)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GitTag.self, from: data)

        XCTAssertEqual(decoded.id, tag.id)
        XCTAssertEqual(decoded.name, tag.name)
        XCTAssertEqual(decoded.commitHash, tag.commitHash)
    }
}