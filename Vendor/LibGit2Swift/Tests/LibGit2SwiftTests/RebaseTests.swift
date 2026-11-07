import Foundation
@testable import LibGit2Swift
import XCTest

final class RebaseTests: LibGit2SwiftTestCase {
    func testRebaseCurrentBranchOntoAnotherBranch() throws {
        try testRepo.createFileAndCommit(
            fileName: "base.txt",
            content: "base",
            message: "Base commit"
        )
        let mainBranch = try LibGit2.getCurrentBranch(at: testRepo.repositoryPath)
        let featureBranch = "feature/rebase"
        _ = try LibGit2.createBranch(
            named: featureBranch,
            at: testRepo.repositoryPath,
            checkout: true
        )
        try testRepo.createFileAndCommit(
            fileName: "feature.txt",
            content: "feature",
            message: "Feature commit"
        )

        try LibGit2.checkout(branch: mainBranch, at: testRepo.repositoryPath, verbose: false)
        try testRepo.createFileAndCommit(
            fileName: "upstream.txt",
            content: "upstream",
            message: "Upstream commit"
        )
        try LibGit2.checkout(branch: featureBranch, at: testRepo.repositoryPath, verbose: false)

        try LibGit2.rebase(
            at: testRepo.repositoryPath,
            upstream: mainBranch,
            onto: mainBranch,
            verbose: false
        )

        XCTAssertEqual(try LibGit2.getCurrentBranch(at: testRepo.repositoryPath), featureBranch)
        XCTAssertEqual(try LibGit2.repositoryState(at: testRepo.repositoryPath), .none)
        XCTAssertEqual(try LibGit2.getCommitCount(at: testRepo.repositoryPath), 3)
        XCTAssertEqual(try testRepo.readFile("upstream.txt"), "upstream")
        XCTAssertEqual(try testRepo.readFile("feature.txt"), "feature")
    }

    func testRebaseContinueAfterResolvingConflict() throws {
        try testRepo.createFileAndCommit(
            fileName: "shared.txt",
            content: "base",
            message: "Base commit"
        )
        let mainBranch = try LibGit2.getCurrentBranch(at: testRepo.repositoryPath)
        let featureBranch = "feature/rebase-conflict"
        _ = try LibGit2.createBranch(
            named: featureBranch,
            at: testRepo.repositoryPath,
            checkout: true
        )
        try "feature".write(
            to: testRepo.tempDirectory.appendingPathComponent("shared.txt"),
            atomically: true,
            encoding: .utf8
        )
        try LibGit2.addFiles(["shared.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Feature change", at: testRepo.repositoryPath, verbose: false)

        try LibGit2.checkout(branch: mainBranch, at: testRepo.repositoryPath, verbose: false)
        try "main".write(
            to: testRepo.tempDirectory.appendingPathComponent("shared.txt"),
            atomically: true,
            encoding: .utf8
        )
        try LibGit2.addFiles(["shared.txt"], at: testRepo.repositoryPath)
        _ = try LibGit2.createCommit(message: "Main change", at: testRepo.repositoryPath, verbose: false)
        try LibGit2.checkout(branch: featureBranch, at: testRepo.repositoryPath, verbose: false)

        XCTAssertThrowsError(
            try LibGit2.rebase(
                at: testRepo.repositoryPath,
                upstream: mainBranch,
                onto: mainBranch,
                verbose: false
            )
        ) { error in
            guard case LibGit2Error.mergeConflict = error else {
                return XCTFail("expected mergeConflict, got \(error)")
            }
        }
        XCTAssertTrue(try LibGit2.repositoryState(at: testRepo.repositoryPath).isRebase)

        try "resolved".write(
            to: testRepo.tempDirectory.appendingPathComponent("shared.txt"),
            atomically: true,
            encoding: .utf8
        )
        try LibGit2.addFiles(["shared.txt"], at: testRepo.repositoryPath)
        try LibGit2.continueRebase(at: testRepo.repositoryPath, verbose: false)

        XCTAssertEqual(try LibGit2.repositoryState(at: testRepo.repositoryPath), .none)
        XCTAssertEqual(try testRepo.readFile("shared.txt"), "resolved")
        XCTAssertFalse(try LibGit2.hasUncommittedChanges(at: testRepo.repositoryPath, verbose: false))
    }
}
