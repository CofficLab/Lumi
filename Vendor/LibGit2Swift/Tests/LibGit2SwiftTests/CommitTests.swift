import Foundation
@testable import LibGit2Swift
import XCTest

/// Commit 相关功能的测试
final class CommitTests: LibGit2SwiftTestCase {
    // MARK: - Commit List Tests

    func testGetCommitListEmptyRepository() throws {
        // 空仓库应该没有提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertTrue(commits.isEmpty, "Empty repository should have no commits")
    }

    func testGetCommitListSingleCommit() throws {
        // 创建单个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        XCTAssertEqual(commits.count, 1, "Should have exactly one commit")
        XCTAssertEqual(commits.first?.message, "First commit", "Commit message should match")
    }

    func testGetCommitListMultipleCommits() throws {
        // 创建多个提交（添加延迟确保时间顺序）
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Commit 1"
        )

        Thread.sleep(forTimeInterval: 0.01) // 10ms delay

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Commit 2"
        )

        Thread.sleep(forTimeInterval: 0.01) // 10ms delay

        try testRepo.createFileAndCommit(
            fileName: "file3.txt",
            content: "Content 3",
            message: "Commit 3"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        XCTAssertEqual(commits.count, 3, "Should have exactly three commits")

        // 验证提交顺序（最新的在前）
        XCTAssertEqual(commits[0].message, "Commit 3", "First commit should be the latest")
        XCTAssertEqual(commits[1].message, "Commit 2", "Second commit should be the middle")
        XCTAssertEqual(commits[2].message, "Commit 1", "Third commit should be the oldest")
    }

    // MARK: - Commit Pagination Tests

    func testGetCommitListWithPagination() throws {
        // 创建多个提交
        for i in 1...10 {
            try testRepo.createFileAndCommit(
                fileName: "file\(i).txt",
                content: "Content \(i)",
                message: "Commit \(i)"
            )
        }

        // 获取第一页
        let page1 = try LibGit2.getCommitListWithPagination(at: testRepo.repositoryPath, page: 0, size: 3)
        XCTAssertEqual(page1.count, 3, "First page should have 3 commits")

        // 获取第二页
        let page2 = try LibGit2.getCommitListWithPagination(at: testRepo.repositoryPath, page: 1, size: 3)
        XCTAssertEqual(page2.count, 3, "Second page should have 3 commits")

        // 验证不同页的提交不同
        let page1Hashes = Set(page1.map { $0.hash })
        let page2Hashes = Set(page2.map { $0.hash })
        let intersection = page1Hashes.intersection(page2Hashes)
        XCTAssertTrue(intersection.isEmpty, "Different pages should have different commits")
    }

    func testGetCommitListWithPaginationBeyondEnd() throws {
        // 创建几个提交
        for i in 1...3 {
            try testRepo.createFileAndCommit(
                fileName: "file\(i).txt",
                content: "Content \(i)",
                message: "Commit \(i)"
            )
        }

        // 请求超出范围的页
        let page = try LibGit2.getCommitListWithPagination(at: testRepo.repositoryPath, page: 10, size: 3)
        XCTAssertTrue(page.isEmpty, "Page beyond available commits should be empty")
    }

    func testGetCommitGraphListIncludesCommitsOutsideCurrentHead() throws {
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        let featureBranch = "feature-graph"
        _ = try LibGit2.createBranch(named: featureBranch, at: testRepo.repositoryPath)
        try LibGit2.checkout(branch: featureBranch, at: testRepo.repositoryPath, verbose: false)
        try testRepo.createFileAndCommit(
            fileName: "feature.txt",
            content: "Feature content",
            message: "Feature graph commit"
        )

        try LibGit2.checkout(branch: "main", at: testRepo.repositoryPath, verbose: false)
        try testRepo.createFileAndCommit(
            fileName: "main.txt",
            content: "Main content",
            message: "Main graph commit"
        )

        let headCommits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let graphCommits = try LibGit2.getCommitGraphList(at: testRepo.repositoryPath)

        XCTAssertFalse(
            headCommits.contains { $0.message == "Feature graph commit" },
            "HEAD history should not include commits reachable only from another branch"
        )
        XCTAssertTrue(
            graphCommits.contains { $0.message == "Feature graph commit" },
            "Graph history should include commits reachable from all branch refs"
        )
        XCTAssertTrue(
            graphCommits.contains { $0.refs.contains("refs/heads/\(featureBranch)") },
            "Graph commits should include branch refs for UI decoration"
        )
    }

    func testGetCommitGraphListIncludesAnnotatedTagReference() throws {
        try testRepo.createFileAndCommit(
            fileName: "tagged.txt",
            content: "Tagged content",
            message: "Tagged graph commit"
        )

        let taggedCommit = try XCTUnwrap(LibGit2.getCommitList(at: testRepo.repositoryPath).first)
        try LibGit2.createTag(
            named: "v-graph-annotated",
            message: "Annotated graph tag",
            at: taggedCommit.hash,
            in: testRepo.repositoryPath,
            verbose: false
        )

        let graphCommits = try LibGit2.getCommitGraphList(at: testRepo.repositoryPath)
        let graphCommit = try XCTUnwrap(graphCommits.first { $0.hash == taggedCommit.hash })

        XCTAssertTrue(graphCommit.refs.contains("refs/tags/v-graph-annotated"))
        XCTAssertTrue(graphCommit.tags.contains("v-graph-annotated"))
    }

    func testGetCommitGraphListPreservesTopologicalOrder() throws {
        try testRepo.createFileAndCommit(
            fileName: "initial.txt",
            content: "Initial content",
            message: "Initial commit"
        )

        let featureBranch = "feature-topology"
        _ = try LibGit2.createBranch(named: featureBranch, at: testRepo.repositoryPath)
        try LibGit2.checkout(branch: featureBranch, at: testRepo.repositoryPath, verbose: false)
        try testRepo.createFileAndCommit(
            fileName: "feature.txt",
            content: "Feature content",
            message: "Feature topology commit"
        )

        try LibGit2.checkout(branch: "main", at: testRepo.repositoryPath, verbose: false)
        try testRepo.createFileAndCommit(
            fileName: "main.txt",
            content: "Main content",
            message: "Main topology commit"
        )

        let graphCommits = try LibGit2.getCommitGraphList(at: testRepo.repositoryPath)
        let indexByHash = Dictionary(uniqueKeysWithValues: graphCommits.enumerated().map { ($0.element.hash, $0.offset) })

        for commit in graphCommits {
            let commitIndex = try XCTUnwrap(indexByHash[commit.hash])
            for parentHash in commit.parentHashes {
                if let parentIndex = indexByHash[parentHash] {
                    XCTAssertLessThan(
                        commitIndex,
                        parentIndex,
                        "Child commits must appear before their parents in graph history"
                    )
                }
            }
        }
    }

    func testGetCommitGraphListWithPagination() throws {
        for i in 1...8 {
            try testRepo.createFileAndCommit(
                fileName: "graph-page-\(i).txt",
                content: "Content \(i)",
                message: "Graph page commit \(i)"
            )
        }

        let page1 = try LibGit2.getCommitGraphListWithPagination(at: testRepo.repositoryPath, page: 0, size: 3)
        let page2 = try LibGit2.getCommitGraphListWithPagination(at: testRepo.repositoryPath, page: 1, size: 3)

        XCTAssertEqual(page1.count, 3)
        XCTAssertEqual(page2.count, 3)
        XCTAssertTrue(Set(page1.map(\.hash)).intersection(Set(page2.map(\.hash))).isEmpty)
    }

    // MARK: - Commit Detail Tests

    func testGetCommitDetail() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Test commit message",
            authorName: "Test Author",
            authorEmail: "test@author.com"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        guard let commit = commits.first else {
            XCTFail("Should have at least one commit")
            return
        }

        // 获取详细信息
        let detail = try LibGit2.getCommitDetail(commitHash: commit.hash, at: testRepo.repositoryPath)

        XCTAssertNotNil(detail, "Commit detail should not be nil")
        XCTAssertEqual(detail?.message, "Test commit message", "Message should match")
        XCTAssertEqual(detail?.author, "Test Author", "Author should match")
        XCTAssertEqual(detail?.email, "test@author.com", "Email should match")
        XCTAssertNotNil(detail?.date, "Date should not be nil")
        XCTAssertNotNil(detail?.hash, "Hash should not be nil")
    }

    // MARK: - Commit Properties Tests

    func testCommitProperties() throws {
        // 创建提交
        let testMessage = "Test commit with properties"
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: testMessage
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        guard let commit = commits.first else {
            XCTFail("Should have at least one commit")
            return
        }

        // 验证必需属性
        XCTAssertFalse(commit.id.isEmpty, "Commit ID should not be empty")
        XCTAssertFalse(commit.hash.isEmpty, "Commit hash should not be empty")
        XCTAssertFalse(commit.author.isEmpty, "Author should not be empty")
        XCTAssertFalse(commit.email.isEmpty, "Email should not be empty")
        XCTAssertEqual(commit.message, testMessage, "Message should match")
        // Body 是提交消息的第一行之后的内容，对于单行提交消息，body 为空
        XCTAssertTrue(commit.body.isEmpty || commit.body == testMessage, "Body should be empty for simple one-line commit, or match message")
        XCTAssertNotNil(commit.date, "Date should not be nil")

        // refs 和 tags 可以为空
        XCTAssertNotNil(commit.refs, "Refs should not be nil")
        XCTAssertNotNil(commit.tags, "Tags should not be nil")
    }

    // MARK: - Branch Commit Tests

    func testGetCommitsOnBranch() throws {
        // 创建主分支提交
        for i in 1...3 {
            try testRepo.createFileAndCommit(
                fileName: "main\(i).txt",
                content: "Main content \(i)",
                message: "Main commit \(i)"
            )
        }

        // 创建并切换到新分支
        let branchName = TestDataGenerator.randomBranchName()
        try LibGit2.createBranch(named: branchName, at: testRepo.repositoryPath, checkout: true)

        // 在新分支上创建提交
        for i in 1...2 {
            try testRepo.createFileAndCommit(
                fileName: "branch\(i).txt",
                content: "Branch content \(i)",
                message: "Branch commit \(i)"
            )
        }

        // 获取主分支的提交（应该有3个初始提交）
        let mainCommits = try LibGit2.getCommitList(on: "main", at: testRepo.repositoryPath)
        XCTAssertEqual(mainCommits.count, 3, "Main branch should have exactly 3 commits")

        // 获取新分支的提交（应该有3个继承的 + 2个自己的 = 5个）
        let branchCommits = try LibGit2.getCommitList(on: branchName, at: testRepo.repositoryPath)
        XCTAssertEqual(branchCommits.count, 5, "New branch should have exactly 5 commits (3 inherited + 2 new)")
    }

    // MARK: - Commit with Tags Tests

    func testGetCommitWithTags() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Tagged commit"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        guard let commit = commits.first else {
            XCTFail("Should have at least one commit")
            return
        }

        // 创建轻量标签（直接引用提交）
        try LibGit2.createTag(named: "v1.0.0", at: commit.hash, in: testRepo.repositoryPath, verbose: false)

        // 重新获取提交列表以包含标签信息
        let updatedCommits = try LibGit2.getCommitList(at: testRepo.repositoryPath)

        // 验证标签信息
        let hasTag = updatedCommits.contains { commit in
            commit.tags.contains("v1.0.0")
        }

        XCTAssertTrue(hasTag, "Commit should have tag information")
    }

    // MARK: - Error Handling Tests

    func testGetCommitDetailInvalidHash() throws {
        // 创建提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Test commit"
        )

        let invalidHash = "invalid_hash_12345"

        // 尝试获取不存在的提交详情
        XCTAssertThrowsError(
            try LibGit2.getCommitDetail(commitHash: invalidHash, at: testRepo.repositoryPath)
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for invalid hash")
        }
    }

    func testGetCommitsOnNonExistentBranch() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "test.txt",
            content: "Test content",
            message: "Initial commit"
        )

        let nonExistentBranch = "nonexistent_branch"

        // 尝试获取不存在分支的提交
        XCTAssertThrowsError(
            try LibGit2.getCommitList(on: nonExistentBranch, at: testRepo.repositoryPath)
        ) { error in
            XCTAssertTrue(error is LibGit2Error, "Should throw LibGit2Error for non-existent branch")
        }
    }

    // MARK: - Performance Tests

    func testCommitListPerformance() throws {
        // 创建多个提交
        for i in 1...50 {
            try testRepo.createFileAndCommit(
                fileName: "file\(i).txt",
                content: "Content \(i)",
                message: "Commit \(i)"
            )
        }

        // 测试获取提交列表的性能
        measure {
            _ = try? LibGit2.getCommitList(at: testRepo.repositoryPath)
        }
    }

    // MARK: - Parent Hashes Tests

    /// 测试初始提交没有父提交
    func testInitialCommitHasNoParents() throws {
        // 创建第一个提交（初始提交）
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "Initial commit"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have exactly one commit")

        let initialCommit = commits[0]
        XCTAssertTrue(initialCommit.parentHashes.isEmpty, "Initial commit should have no parent hashes")
        XCTAssertTrue(initialCommit.isInitialCommit, "Should be identified as initial commit")
        XCTAssertFalse(initialCommit.isMergeCommit, "Initial commit should not be a merge commit")
    }

    /// 测试普通提交有一个父提交
    func testRegularCommitHasOneParent() throws {
        // 创建两个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 2, "Should have exactly two commits")

        // 最新的提交（index 0）应该有一个父提交，指向第一个提交
        let latestCommit = commits[0]
        XCTAssertEqual(latestCommit.parentHashes.count, 1, "Regular commit should have exactly one parent")
        XCTAssertEqual(latestCommit.parentHashes[0], commits[1].hash, "Parent hash should match the first commit")
        XCTAssertFalse(latestCommit.isInitialCommit, "Second commit should not be initial commit")
        XCTAssertFalse(latestCommit.isMergeCommit, "Regular commit should not be a merge commit")

        // 第一个提交（初始提交）没有父提交
        let firstCommit = commits[1]
        XCTAssertTrue(firstCommit.parentHashes.isEmpty, "First commit should have no parents")
    }

    /// 测试多个提交的父提交链完整性
    func testCommitParentChain() throws {
        // 创建 5 个提交
        for i in 1...5 {
            try testRepo.createFileAndCommit(
                fileName: "file\(i).txt",
                content: "Content \(i)",
                message: "Commit \(i)"
            )
        }

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 5, "Should have exactly 5 commits")

        // 验证父提交链：每个提交的 parent 应该指向下一个（更早的）提交
        for i in 0..<(commits.count - 1) {
            XCTAssertEqual(commits[i].parentHashes.count, 1,
                "Commit \(i) should have exactly one parent")
            XCTAssertEqual(commits[i].parentHashes[0], commits[i + 1].hash,
                "Commit \(i)'s parent should be commit \(i + 1)")
        }

        // 最后一个（最老的）提交是初始提交
        XCTAssertTrue(commits.last!.parentHashes.isEmpty,
            "The oldest commit should be the initial commit with no parents")
    }

    /// 测试 getCommitDetail 也返回正确的 parentHashes
    func testGetCommitDetailWithParentHashes() throws {
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let secondCommit = commits[0] // 最新的

        // 通过 getCommitDetail 获取详细信息
        let detail = try LibGit2.getCommitDetail(commitHash: secondCommit.hash, at: testRepo.repositoryPath)
        XCTAssertNotNil(detail, "Detail should not be nil")
        XCTAssertEqual(detail?.parentHashes.count, 1, "Detail should have one parent hash")
        XCTAssertEqual(detail?.parentHashes[0], commits[1].hash, "Parent hash should match first commit")
    }

    // MARK: - Undo Commit (Reset Mixed) Tests

    /// 测试撤销最新的提交（普通提交）
    /// 验证 reset --mixed 后：
    /// 1. 提交被移除
    /// 2. 文件变更保留在工作区（未暂存状态）
    /// 3. 文件内容不变
    func testUndoLastCommitWithMixedReset() throws {
        // 创建两个提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        // 验证初始状态：2 个提交
        var commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 2, "Should have 2 commits before undo")
        XCTAssertEqual(commits[0].message, "Second commit")

        // 获取最新提交的父提交哈希
        let latestCommit = commits[0]
        let parentHash = latestCommit.parentHashes[0]

        // 执行 mixed reset（撤销最新提交）
        try LibGit2.reset(to: parentHash, mode: "mixed", at: testRepo.repositoryPath, verbose: false)

        // 验证：只剩 1 个提交
        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit after undo")
        XCTAssertEqual(commits[0].message, "First commit", "Remaining commit should be the first one")

        // 验证：file2.txt 仍然存在于磁盘
        assertFileExists("file2.txt", in: testRepo)

        // 验证：file2.txt 内容不变
        let content = try testRepo.readFile("file2.txt")
        XCTAssertEqual(content, "Content 2", "File content should be preserved after undo")

        // 验证：file2.txt 出现在未暂存文件列表中（工作区变更）
        let unstagedFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: false)
        let hasFile2 = unstagedFiles.contains { $0.file == "file2.txt" }
        XCTAssertTrue(hasFile2, "file2.txt should appear as unstaged change after undo")
    }

    /// 测试撤销提交后，文件变更可以重新提交
    func testUndoAndRecommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        // 创建第二个提交
        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        // 撤销第二个提交
        var commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let parentHash = commits[0].parentHashes[0]
        try LibGit2.reset(to: parentHash, mode: "mixed", at: testRepo.repositoryPath, verbose: false)

        // 验证只剩 1 个提交
        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1)

        // 将撤销的文件重新添加并提交（用新的提交消息）
        try LibGit2.addFiles(["file2.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Recommitted: Second commit", at: testRepo.repositoryPath, verbose: false)

        // 验证：重新提交成功
        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 2, "Should have 2 commits after recommit")
        XCTAssertEqual(commits[0].message, "Recommitted: Second commit", "Latest commit should be the recommit")
    }

    /// 测试连续撤销多个提交
    func testUndoMultipleCommitsSequentially() throws {
        // 创建 3 个提交
        try testRepo.createFileAndCommit(fileName: "file1.txt", content: "C1", message: "Commit 1")
        try testRepo.createFileAndCommit(fileName: "file2.txt", content: "C2", message: "Commit 2")
        try testRepo.createFileAndCommit(fileName: "file3.txt", content: "C3", message: "Commit 3")

        // 验证有 3 个提交
        var commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 3)

        // 撤销第 3 个提交
        let parentHash3 = commits[0].parentHashes[0]
        try LibGit2.reset(to: parentHash3, mode: "mixed", at: testRepo.repositoryPath, verbose: false)

        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 2, "Should have 2 commits after first undo")
        XCTAssertEqual(commits[0].message, "Commit 2")

        // 撤销第 2 个提交
        let parentHash2 = commits[0].parentHashes[0]
        try LibGit2.reset(to: parentHash2, mode: "mixed", at: testRepo.repositoryPath, verbose: false)

        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit after second undo")
        XCTAssertEqual(commits[0].message, "Commit 1")

        // 验证所有文件仍然存在
        assertFileExists("file1.txt", in: testRepo)
        assertFileExists("file2.txt", in: testRepo)
        assertFileExists("file3.txt", in: testRepo)
    }

    /// 测试 soft reset（撤销提交但保留暂存区）
    func testUndoCommitWithSoftReset() throws {
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        // 获取父提交
        var commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let parentHash = commits[0].parentHashes[0]

        // 执行 soft reset
        try LibGit2.reset(to: parentHash, mode: "soft", at: testRepo.repositoryPath, verbose: false)

        // 验证只剩 1 个提交
        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit after soft reset")

        // 验证：file2.txt 出现在暂存区（staged）
        let stagedFiles = try LibGit2.getDiffFileList(at: testRepo.repositoryPath, staged: true)
        let hasFile2Staged = stagedFiles.contains { $0.file == "file2.txt" }
        XCTAssertTrue(hasFile2Staged, "file2.txt should be staged after soft reset")
    }

    /// 测试 hard reset（撤销提交并丢弃所有变更）
    func testUndoCommitWithHardReset() throws {
        try testRepo.createFileAndCommit(
            fileName: "file1.txt",
            content: "Content 1",
            message: "First commit"
        )

        try testRepo.createFileAndCommit(
            fileName: "file2.txt",
            content: "Content 2",
            message: "Second commit"
        )

        // 获取父提交
        var commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let parentHash = commits[0].parentHashes[0]

        // 执行 hard reset
        try LibGit2.reset(to: parentHash, mode: "hard", at: testRepo.repositoryPath, verbose: false)

        // 验证只剩 1 个提交
        commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit after hard reset")

        // 验证：file2.txt 被删除（变更被丢弃）
        assertFileNotExists("file2.txt", in: testRepo)
    }

    // MARK: - Amend Commit Tests

    func testAmendCommit() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original content",
            message: "Original message"
        )

        // 获取原始提交hash
        let originalCommits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        let originalHash = originalCommits[0].hash

        // 修改文件并暂存（必须有变更才能amend）
        try "Modified content".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // Amend提交（修改内容但不修改消息）
        _ = try LibGit2.amendCommit(message: nil, at: testRepo.repositoryPath, verbose: false)

        // 验证提交被修改
        let amendedCommits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(amendedCommits.count, 1, "Should still have 1 commit")
        XCTAssertNotEqual(amendedCommits[0].hash, originalHash, "Commit hash should change after amend")
        XCTAssertEqual(amendedCommits[0].message, "Original message", "Message should remain unchanged")
    }

    func testAmendCommitWithNewMessage() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original content",
            message: "Original message"
        )

        // 需要暂存变更才能amend
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // Amend提交，修改消息
        let newMessage = "Amended message"
        _ = try LibGit2.amendCommit(message: newMessage, at: testRepo.repositoryPath, verbose: false)

        // 验证消息已修改
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits[0].message, newMessage, "Message should be updated")
    }

    func testAmendCommitWithContentAndMessage() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Original",
            message: "Original message"
        )

        // 修改文件内容
        try "New content".write(to: testRepo.tempDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // Amend提交，同时修改内容和消息
        let newMessage = "Updated content and message"
        _ = try LibGit2.amendCommit(message: newMessage, at: testRepo.repositoryPath, verbose: false)

        // 验证提交已修改
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits[0].message, newMessage, "Message should be updated")
        XCTAssertEqual(commits.count, 1, "Should have 1 commit")

        // 验证文件内容
        let content = try testRepo.readFile("file.txt")
        XCTAssertEqual(content, "New content", "File content should be updated")
    }

    func testAmendCommitNoChanges() throws {
        // 创建初始提交
        try testRepo.createFileAndCommit(
            fileName: "file.txt",
            content: "Content",
            message: "Original message"
        )

        // 暂存文件（确保index有内容）
        try LibGit2.addFiles(["file.txt"], at: testRepo.repositoryPath)

        // Amend（即使内容相同也应该成功）
        _ = try LibGit2.amendCommit(message: nil, at: testRepo.repositoryPath, verbose: false)

        // 验证提交仍然存在
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit")
    }

    func testAmendCommitEmptyRepository() throws {
        // 空仓库没有HEAD，amend应该失败
        XCTAssertThrowsError(try LibGit2.amendCommit(message: "test", at: testRepo.repositoryPath, verbose: false)) { error in
            XCTAssertTrue(error is LibGit2Error)
        }
    }

    // MARK: - Add and Commit Tests

    func testAddAndCommit() throws {
        // 创建文件
        try "Content".write(to: testRepo.tempDirectory.appendingPathComponent("newfile.txt"), atomically: true, encoding: .utf8)

        // 使用addAndCommit一次性添加并提交
        _ = try LibGit2.addAndCommit(files: ["newfile.txt"], message: "Add and commit", at: testRepo.repositoryPath, verbose: false)

        // 验证提交已创建
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1, "Should have 1 commit")
        XCTAssertEqual(commits[0].message, "Add and commit")

        // 验证文件已提交
        assertFileExists("newfile.txt", in: testRepo)
    }

    func testAddAndCommitMultipleFiles() throws {
        // 创建多个文件
        for i in 1...3 {
            try "Content \(i)".write(to: testRepo.tempDirectory.appendingPathComponent("file\(i).txt"), atomically: true, encoding: .utf8)
        }

        // 使用addAndCommit添加多个文件
        _ = try LibGit2.addAndCommit(files: ["file1.txt", "file2.txt", "file3.txt"], message: "Add multiple files", at: testRepo.repositoryPath, verbose: false)

        // 验证所有文件已提交
        let commits = try LibGit2.getCommitList(at: testRepo.repositoryPath)
        XCTAssertEqual(commits.count, 1)

        assertFileExists("file1.txt", in: testRepo)
        assertFileExists("file2.txt", in: testRepo)
        assertFileExists("file3.txt", in: testRepo)
    }

    func testCommitCountAndFirstCommitDate() throws {
        try testRepo.createFileAndCommit(
            fileName: "first.txt",
            content: "First",
            message: "First commit"
        )
        try testRepo.createFileAndCommit(
            fileName: "second.txt",
            content: "Second",
            message: "Second commit"
        )

        XCTAssertEqual(
            try LibGit2.getCommitCount(at: testRepo.repositoryPath),
            2
        )
        XCTAssertNotNil(try LibGit2.getFirstCommitDate(at: testRepo.repositoryPath))

        let token = GitCancellationToken()
        token.cancel()
        XCTAssertThrowsError(
            try LibGit2.getCommitCount(at: testRepo.repositoryPath, cancellation: token)
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }
}
