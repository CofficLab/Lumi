#if canImport(XCTest)
import Foundation
import XCTest
@testable import Lumi

final class AgentGitHubToolsPluginTests: XCTestCase {

    func testGitHubFileContentDecodesBase64Payload() {
        let file = GitHubFileContent(
            name: "README.md",
            path: "README.md",
            sha: "abc",
            size: 5,
            url: "https://api.github.com/repos/o/r/contents/README.md",
            htmlUrl: "https://github.com/o/r/blob/main/README.md",
            gitUrl: "https://api.github.com/repos/o/r/git/blobs/abc",
            downloadUrl: nil,
            type: "file",
            content: Data("hello".utf8).base64EncodedString(),
            encoding: "base64"
        )

        XCTAssertEqual(file.decodedContent, "hello")
    }

    func testGitHubRepositoryDecodesSnakeCasePayload() throws {
        let payload = """
        {
          "id": 1,
          "name": "repo",
          "full_name": "owner/repo",
          "description": "test repo",
          "html_url": "https://github.com/owner/repo",
          "language": "Swift",
          "stargazers_count": 42,
          "forks_count": 7,
          "open_issues_count": 3,
          "owner": {
            "login": "owner",
            "id": 99,
            "avatar_url": "https://example.com/avatar.png",
            "html_url": "https://github.com/owner",
            "type": "User"
          },
          "created_at": "2024-01-01T00:00:00Z",
          "updated_at": "2024-01-02T00:00:00Z",
          "default_branch": "main",
          "private": false
        }
        """

        let repo = try JSONDecoder().decode(GitHubRepository.self, from: Data(payload.utf8))

        XCTAssertEqual(repo.fullName, "owner/repo")
        XCTAssertEqual(repo.stargazersCount, 42)
        XCTAssertEqual(repo.owner.login, "owner")
        XCTAssertEqual(repo.defaultBranch, "main")
        XCTAssertFalse(repo.isPrivate)
    }
}
#endif
