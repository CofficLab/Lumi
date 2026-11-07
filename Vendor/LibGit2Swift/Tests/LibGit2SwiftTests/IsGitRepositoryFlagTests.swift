import Foundation
@testable import LibGit2Swift
import Clibgit2
import XCTest

/// 测试 isGitRepository 在不同 flag 下的行为差异
///
/// 问题场景：
/// - GIT_REPOSITORY_OPEN_NO_SEARCH 要求路径必须精确是仓库根目录
/// - 如果传入子目录路径，即使该目录属于某个仓库，也会返回 false
/// - 这可能导致 Agent 工具在某些上下文中无法正确识别仓库
final class IsGitRepositoryFlagTests: LibGit2SwiftTestCase {

    // MARK: - 测试 NO_SEARCH flag 的限制

    /// 测试：使用 NO_SEARCH flag 时，传入仓库根目录应返回 true
    func testNoSearchFlagWithRootDirectory() throws {
        // 仓库根目录
        let rootPath = testRepo.repositoryPath
        
        // 使用 NO_SEARCH flag（当前实现）
        var repo: OpaquePointer? = nil
        let resultNoSearch = git_repository_open_ext(
            &repo, 
            rootPath, 
            GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, 
            nil
        )
        if repo != nil { git_repository_free(repo) }
        
        XCTAssertTrue(resultNoSearch == 0, 
            "NO_SEARCH flag with root directory should return true (result: \(resultNoSearch))")
    }

    /// 测试：使用 NO_SEARCH flag 时，传入子目录应返回 false
    func testNoSearchFlagWithSubdirectory() throws {
        // 创建子目录
        let subDir = testRepo.tempDirectory.appendingPathComponent("subdirectory")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // 使用 NO_SEARCH flag（当前实现）
        var repo: OpaquePointer? = nil
        let resultNoSearch = git_repository_open_ext(
            &repo, 
            subDir.path, 
            GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, 
            nil
        )
        if repo != nil { git_repository_free(repo) }
        
        XCTAssertFalse(resultNoSearch == 0, 
            "NO_SEARCH flag with subdirectory should return false (result: \(resultNoSearch))")
    }

    /// 测试：使用默认 flag 时，传入子目录应返回 true（向上搜索找到仓库）
    func testDefaultFlagWithSubdirectory() throws {
        // 创建子目录
        let subDir = testRepo.tempDirectory.appendingPathComponent("subdirectory")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // 使用默认 flag（0 = 允许向上搜索）
        var repo: OpaquePointer? = nil
        let resultDefault = git_repository_open_ext(
            &repo, 
            subDir.path, 
            0,  // 默认 flag，允许向上搜索
            nil
        )
        if repo != nil { git_repository_free(repo) }
        
        XCTAssertTrue(resultDefault == 0, 
            "Default flag with subdirectory should return true (向上搜索找到仓库, result: \(resultDefault))")
    }

    /// 测试：使用默认 flag 时，传入仓库根目录也应返回 true
    func testDefaultFlagWithRootDirectory() throws {
        // 仓库根目录
        let rootPath = testRepo.repositoryPath
        
        // 使用默认 flag
        var repo: OpaquePointer? = nil
        let resultDefault = git_repository_open_ext(
            &repo, 
            rootPath, 
            0, 
            nil
        )
        if repo != nil { git_repository_free(repo) }
        
        XCTAssertTrue(resultDefault == 0, 
            "Default flag with root directory should return true (result: \(resultDefault))")
    }

    // MARK: - 测试 LibGit2.isGitRepository 当前实现

    /// 测试：当前 LibGit2.isGitRepository 实现对子目录的行为
    /// 修复后：使用默认 flag (0)，子目录应该返回 true（向上搜索找到仓库）
    func testCurrentIsGitRepositoryImplementationWithSubdirectory() throws {
        // 创建子目录
        let subDir = testRepo.tempDirectory.appendingPathComponent("subdirectory")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        
        // 修复后的实现使用默认 flag (0)，允许向上搜索
        let isRepo = LibGit2.isGitRepository(at: subDir.path)
        
        // 修复后：子目录应该返回 true（向上搜索找到仓库）
        XCTAssertTrue(isRepo, 
            "Fixed isGitRepository with subdirectory returns true (default flag allows upward search)")
    }

    /// 测试：当前 LibGit2.isGitRepository 实现对根目录的行为
    func testCurrentIsGitRepositoryImplementationWithRoot() throws {
        let rootPath = testRepo.repositoryPath
        
        let isRepo = LibGit2.isGitRepository(at: rootPath)
        
        XCTAssertTrue(isRepo, 
            "Current isGitRepository with root directory returns true")
    }

    // MARK: - 测试非 Git 目录

    /// 测试：非 Git 目录无论使用哪种 flag 都应返回 false
    func testNonGitDirectoryWithBothFlags() throws {
        // 创建非 Git 目录
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibGit2SwiftTests")
            .appendingPathComponent("nongit_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // NO_SEARCH flag
        var repo1: OpaquePointer? = nil
        let resultNoSearch = git_repository_open_ext(
            &repo1, 
            tempDir.path, 
            GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, 
            nil
        )
        if repo1 != nil { git_repository_free(repo1) }
        
        // 默认 flag
        var repo2: OpaquePointer? = nil
        let resultDefault = git_repository_open_ext(
            &repo2, 
            tempDir.path, 
            0, 
            nil
        )
        if repo2 != nil { git_repository_free(repo2) }
        
        XCTAssertFalse(resultNoSearch == 0, "Non-Git dir with NO_SEARCH should return false")
        XCTAssertFalse(resultDefault == 0, "Non-Git dir with default flag should return false")
    }

    // MARK: - 测试路径解析差异

    /// 测试：路径末尾有斜杠的情况
    func testPathWithTrailingSlash() throws {
        let rootPath = testRepo.repositoryPath
        let pathWithSlash = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        
        // NO_SEARCH flag
        var repo1: OpaquePointer? = nil
        let resultNoSearch = git_repository_open_ext(
            &repo1, 
            pathWithSlash, 
            GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, 
            nil
        )
        if repo1 != nil { git_repository_free(repo1) }
        
        // 默认 flag
        var repo2: OpaquePointer? = nil
        let resultDefault = git_repository_open_ext(
            &repo2, 
            pathWithSlash, 
            0, 
            nil
        )
        if repo2 != nil { git_repository_free(repo2) }
        
        // 记录结果以便调试
        print("Path with trailing slash:")
        print("  NO_SEARCH result: \(resultNoSearch)")
        print("  Default result: \(resultDefault)")
        
        // 两种 flag 对末尾斜杠的处理可能不同
        // 这里只记录结果，不做严格要求
    }

    /// 测试：符号链接路径的情况
    func testSymlinkPath() throws {
        // 在 macOS 上 /var 可能是 /private/var 的符号链接
        // 创建一个符号链接指向测试仓库
        let symlinkPath = testRepo.tempDirectory.appendingPathComponent("symlink_to_repo").path
        
        // 尝试创建符号链接（可能因权限失败）
        do {
            try FileManager.default.createSymbolicLink(
                atPath: symlinkPath,
                withDestinationPath: testRepo.repositoryPath
            )
            
            defer { try? FileManager.default.removeItem(atPath: symlinkPath) }
            
            // NO_SEARCH flag
            var repo1: OpaquePointer? = nil
            let resultNoSearch = git_repository_open_ext(
                &repo1, 
                symlinkPath, 
                GIT_REPOSITORY_OPEN_NO_SEARCH.rawValue, 
                nil
            )
            if repo1 != nil { git_repository_free(repo1) }
            
            // 默认 flag
            var repo2: OpaquePointer? = nil
            let resultDefault = git_repository_open_ext(
                &repo2, 
                symlinkPath, 
                0, 
                nil
            )
            if repo2 != nil { git_repository_free(repo2) }
            
            print("Symlink path:")
            print("  NO_SEARCH result: \(resultNoSearch)")
            print("  Default result: \(resultDefault)")
        } catch {
            print("Skipping symlink test: \(error.localizedDescription)")
        }
    }
}