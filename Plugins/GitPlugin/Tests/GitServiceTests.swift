import Foundation
import Testing
@testable import GitPlugin

@Suite("GitService Tests")
struct GitServiceTests {
    
    @Test("getStatus throws repositoryNotGit for non-git directory")
    func getStatusThrowsForNonGitDirectory() async throws {
        // Create a temporary directory that is NOT a git repository
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-test-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        await #expect(throws: GitServiceError.self) {
            _ = try await GitService.shared.getStatus(path: tempDir.path)
        }
    }
    
    @Test("getStatus throws repositoryNotGit for nonexistent path")
    func getStatusThrowsForNonexistentPath() async throws {
        let fakePath = "/tmp/lumi-nonexistent-\(UUID().uuidString)"
        
        await #expect(throws: GitServiceError.self) {
            _ = try await GitService.shared.getStatus(path: fakePath)
        }
    }
    
    @Test("getDiff throws repositoryNotGit for non-git directory")
    func getDiffThrowsForNonGitDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-test-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        await #expect(throws: GitServiceError.self) {
            _ = try await GitService.shared.getDiff(path: tempDir.path, staged: false, file: nil)
        }
    }
    
    @Test("getLog throws repositoryNotGit for non-git directory")
    func getLogThrowsForNonGitDirectory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("lumi-test-\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        await #expect(throws: GitServiceError.self) {
            _ = try await GitService.shared.getLog(path: tempDir.path, count: 10, branch: nil, file: nil)
        }
    }
}
