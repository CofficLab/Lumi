import Foundation
import Testing
@testable import GitHubKit

@Suite("GitHubAPIService")
struct GitHubAPIServiceTests {
    @Test("仓库搜索参数包含基础分页参数")
    func searchRepositoryParametersIncludeBasePagination() {
        let params = GitHubAPIService().searchRepositoryParameters(
            query: "AppKit language:Swift",
            page: 2,
            perPage: 25,
            sort: nil,
            order: nil
        )

        #expect(params["q"] == "AppKit language:Swift")
        #expect(params["page"] == "2")
        #expect(params["per_page"] == "25")
        #expect(params["sort"] == nil)
        #expect(params["order"] == nil)
    }

    @Test("仓库搜索参数支持排序")
    func searchRepositoryParametersIncludeSortAndOrder() {
        let params = GitHubAPIService().searchRepositoryParameters(
            query: "Combine language:Swift stars:>10",
            page: 1,
            perPage: 8,
            sort: "stars",
            order: "desc"
        )

        #expect(params["sort"] == "stars")
        #expect(params["order"] == "desc")
    }

    @Test("仓库搜索参数忽略空排序字段")
    func searchRepositoryParametersDropEmptySortValues() {
        let params = GitHubAPIService().searchRepositoryParameters(
            query: "Foundation language:Swift",
            page: 1,
            perPage: 8,
            sort: "",
            order: ""
        )

        #expect(params["sort"] == nil)
        #expect(params["order"] == nil)
    }

    @Test("无效基础 URL 构建请求时抛出错误而不是崩溃")
    func buildGetRequestThrowsForInvalidBaseURL() throws {
        let service = GitHubAPIService(baseURL: ":// invalid")

        #expect(throws: GitHubAPIError.self) {
            _ = try service.buildGetRequest(endpoint: "/repos/example/repo")
        }
    }

    @Test("文件内容模型解码 GitHub JSON 字段并提供 UTF-8 文本")
    func fileContentDecodesSnakeCaseFieldsAndContent() throws {
        let json = """
        {
          "name": "README.md",
          "path": "README.md",
          "sha": "abc123",
          "size": 11,
          "url": "https://api.github.com/repos/example/repo/contents/README.md",
          "html_url": "https://github.com/example/repo/blob/main/README.md",
          "git_url": "https://api.github.com/repos/example/repo/git/blobs/abc123",
          "download_url": "https://raw.githubusercontent.com/example/repo/main/README.md",
          "type": "file",
          "content": "SGVsbG8gd29ybGQ=",
          "encoding": "base64"
        }
        """.data(using: .utf8)!

        let content = try JSONDecoder().decode(GitHubFileContent.self, from: json)

        #expect(content.htmlUrl == "https://github.com/example/repo/blob/main/README.md")
        #expect(content.gitUrl == "https://api.github.com/repos/example/repo/git/blobs/abc123")
        #expect(content.downloadUrl == "https://raw.githubusercontent.com/example/repo/main/README.md")
        #expect(content.decodedContent == "Hello world")
    }

    @Test("文件内容解码在无效 Base64 时返回 nil")
    func fileContentDecodedContentReturnsNilForInvalidBase64() {
        let content = GitHubFileContent(
            name: "broken.txt",
            path: "broken.txt",
            sha: "abc123",
            size: 12,
            url: "https://api.github.com/repos/example/repo/contents/broken.txt",
            htmlUrl: "https://github.com/example/repo/blob/main/broken.txt",
            gitUrl: "https://api.github.com/repos/example/repo/git/blobs/abc123",
            downloadUrl: nil,
            type: "file",
            content: "not-base64",
            encoding: "base64"
        )

        #expect(content.decodedContent == nil)
    }

    @Test("API 错误描述覆盖常用错误")
    func apiErrorDescriptionsAreUserFacing() {
        #expect(GitHubAPIError.invalidURL(":// invalid").errorDescription == "无效的 GitHub API URL：:// invalid")
        #expect(GitHubAPIError.httpError(404).errorDescription == "HTTP 错误：404")
        #expect(GitHubAPIError.rateLimited.errorDescription == "API 请求超限，请稍后重试")
        #expect(GitHubAPIError.unauthorized.errorDescription == "认证失败，请检查 GitHub Token")
    }

    @Test("查询参数中的加号被百分号编码")
    func queryPlusSignIsPercentEncoded() throws {
        let service = GitHubAPIService(baseURL: "https://api.github.com")
        let request = try service.buildGetRequest(
            endpoint: "/search/repositories",
            params: ["q": "language:c++"]
        )
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQuery?.contains("q=language%3Ac%2B%2B") == true)
    }

    @Test("查询参数中的 & 与 = 被编码")
    func queryReservedCharactersAreEncoded() throws {
        let service = GitHubAPIService(baseURL: "https://api.github.com")
        let request = try service.buildGetRequest(
            endpoint: "/search/repositories",
            params: ["q": "a&b=c d"]
        )
        let url = try #require(request.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.percentEncodedQuery?.contains("q=a%26b%3Dc%20d") == true)
    }

    @Test("文件路径中的特殊字符被编码且保留斜杠")
    func filePathIsPercentEncoded() {
        #expect(GitHubAPIService.percentEncodePath("docs/My File #1.md") == "docs/My%20File%20%231.md")
    }

    @Test("Issue 关联 PR 对象可解码")
    func issueDecodesPullRequestObject() throws {
        let json = """
        {
          "id": 1,
          "number": 2,
          "title": "Fix",
          "body": null,
          "state": "open",
          "user": {
            "login": "octocat",
            "id": 3,
            "avatar_url": "https://avatar",
            "html_url": "https://github.com/octocat",
            "type": "User"
          },
          "html_url": "https://github.com/a/b/pull/2",
          "repository_url": "https://api.github.com/repos/a/b",
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "closed_at": null,
          "comments": 0,
          "labels": [],
          "milestone": null,
          "pull_request": {
            "url": "https://api.github.com/repos/a/b/pulls/2",
            "html_url": "https://github.com/a/b/pull/2",
            "diff_url": "https://github.com/a/b/pull/2.diff",
            "patch_url": "https://github.com/a/b/pull/2.patch"
          }
        }
        """.data(using: .utf8)!

        let issue = try JSONDecoder().decode(GitHubIssue.self, from: json)
        let pullRequest = try #require(issue.pulledThrough)
        #expect(pullRequest.url == "https://api.github.com/repos/a/b/pulls/2")
        #expect(pullRequest.htmlUrl == "https://github.com/a/b/pull/2")
        #expect(pullRequest.diffUrl == "https://github.com/a/b/pull/2.diff")
    }

    @Test("无 PR 关联的 Issue pull_request 为 nil")
    func issueWithoutPullRequestDecodesToNil() throws {
        let json = """
        {
          "id": 1,
          "number": 2,
          "title": "Bug",
          "body": "desc",
          "state": "closed",
          "user": {
            "login": "octocat",
            "id": 3,
            "avatar_url": "https://avatar",
            "html_url": "https://github.com/octocat",
            "type": null
          },
          "html_url": "https://github.com/a/b/issues/2",
          "repository_url": null,
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "closed_at": "2026-01-02T00:00:00Z",
          "comments": 4,
          "labels": [
            { "id": 9, "name": "bug", "color": "ff0000", "description": null }
          ],
          "milestone": {
            "id": 7,
            "number": 1,
            "title": "v1.0",
            "description": null,
            "state": "open",
            "created_at": "2026-01-01T00:00:00Z",
            "due_on": null,
            "closed_at": null
          }
        }
        """.data(using: .utf8)!

        let issue = try JSONDecoder().decode(GitHubIssue.self, from: json)
        #expect(issue.pulledThrough == nil)
        #expect(issue.state == .closed)
        #expect(issue.labels.first?.name == "bug")
        #expect(issue.milestone?.title == "v1.0")
    }

    @Test("Issue 评论解码 snake_case 字段")
    func issueCommentDecodesSnakeCaseFields() throws {
        let json = """
        {
          "id": 11,
          "user": {
            "login": "octocat",
            "id": 3,
            "avatar_url": "https://avatar",
            "html_url": "https://github.com/octocat",
            "type": "User"
          },
          "body": "Looks good",
          "created_at": "2026-01-01T00:00:00Z",
          "updated_at": "2026-01-02T00:00:00Z",
          "html_url": "https://github.com/a/b/issues/2#issuecomment-11"
        }
        """.data(using: .utf8)!

        let comment = try JSONDecoder().decode(GitHubIssueComment.self, from: json)
        #expect(comment.user.login == "octocat")
        #expect(comment.body == "Looks good")
        #expect(comment.htmlUrl.hasSuffix("#issuecomment-11"))
    }

    @Test("仓库与搜索结果解码包含 private 与 topics 字段")
    func repositoryAndSearchResultDecode() throws {
        let repoJSON = """
        {
          "id": 1,
          "name": "b",
          "full_name": "a/b",
          "description": "demo",
          "html_url": "https://github.com/a/b",
          "language": "Swift",
          "stargazers_count": 42,
          "forks_count": 7,
          "open_issues_count": 3,
          "topics": ["swift", "macos"],
          "pushed_at": "2026-01-01T00:00:00Z",
          "archived": false,
          "fork": false,
          "owner": {
            "login": "a",
            "id": 2,
            "avatar_url": "https://avatar",
            "html_url": "https://github.com/a",
            "type": "Organization"
          },
          "created_at": "2025-01-01T00:00:00Z",
          "updated_at": "2026-01-01T00:00:00Z",
          "default_branch": "main",
          "private": true
        }
        """.data(using: .utf8)!

        let repo = try JSONDecoder().decode(GitHubRepository.self, from: repoJSON)
        #expect(repo.fullName == "a/b")
        #expect(repo.isPrivate == true)
        #expect(repo.topics == ["swift", "macos"])
        #expect(repo.stargazersCount == 42)
        #expect(repo.owner.type == "Organization")

        let searchJSON = """
        { "total_count": 1, "incomplete_results": false, "items": [\(String(data: repoJSON, encoding: .utf8)!)] }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(GitHubSearchResult.self, from: searchJSON)
        #expect(result.totalCount == 1)
        #expect(result.items.first?.name == "b")
    }

    @Test("setTokenProvider 在初始化后注入 Bearer 头")
    func setTokenProviderAppliesBearerHeader() throws {
        final class MutableProvider: GitHubTokenProviding, @unchecked Sendable {
            var token: String? = nil
            var accessToken: String? { token }
        }
        let provider = MutableProvider()
        let service = GitHubAPIService(baseURL: "https://api.github.com", tokenProvider: provider)
        provider.token = "late-token"
        let request = try service.buildGetRequest(endpoint: "/repos/a/b")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer late-token")
    }
}
