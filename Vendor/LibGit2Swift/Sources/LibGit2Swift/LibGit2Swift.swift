import Foundation
import Clibgit2

/// Re-export all public APIs


/// LibGit2Swift - A Swift wrapper for libgit2
///
/// This package provides a type-safe Swift interface to libgit2,
/// replacing shell-based Git operations with native library calls.
///
/// ## Example Usage
///
/// ```swift
/// import LibGit2Swift
///
/// // Check if a path is a Git repository
/// let isRepo = LibGit2.isGitRepository(at: "/path/to/repo")
///
/// // Get the current branch
/// let branch = try LibGit2.getCurrentBranch(at: "/path/to/repo")
///
/// // Get commit history
/// let commits = try LibGit2.getCommitList(at: "/path/to/repo")
///
/// // Add files and commit
/// try LibGit2.addFiles(["file.txt"], at: "/path/to/repo")
/// try LibGit2.createCommit(message: "Add file", at: "/path/to/repo")
/// ```
public enum LibGit2Swift {
    /// Initialize libgit2 (call once at app startup)
    public static func initialize() {
        LibGit2.initialize()
    }

    /// Shutdown libgit2 (call once at app termination)
    public static func shutdown() {
        LibGit2.shutdown()
    }
}
