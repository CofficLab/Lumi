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
        #expect(GitHubAPIError.httpError(404).errorDescription == "HTTP 错误：404")
        #expect(GitHubAPIError.rateLimited.errorDescription == "API 请求超限，请稍后重试")
        #expect(GitHubAPIError.unauthorized.errorDescription == "认证失败，请检查 GitHub Token")
    }
}
