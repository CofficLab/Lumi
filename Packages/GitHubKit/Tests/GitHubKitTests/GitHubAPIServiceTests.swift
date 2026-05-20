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
}
