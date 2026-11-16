import Testing
import Foundation
@testable import BrewManagerPlugin

/// 回归 #654：搜索把 10 个名额先全给 Formula，再用 `10 - formulaLimit.count`
/// 给 Cask。一旦 Formula 满 10 个，Cask 配额恒为 0，docker-desktop 这类明确
/// 匹配的应用被整类丢弃。配额须按类别独立保留，不得让一类饿死另一类。
struct BrewSearchCaskQuotaTests {

    @Test("Formula 满额时 Cask 不得被整类丢弃")
    func casksSurviveWhenFormulaeFillQuota() async throws {
        let service = makeService(formulaCount: 12, caskCount: 3)
        let results = try await service.search(query: "docker")
        let casks = results.filter { $0.isCask }
        let formulae = results.filter { !$0.isCask }
        #expect(casks.count == 3)
        #expect(formulae.count == 10)
        #expect(casks.map(\.name) == ["cask-0", "cask-1", "cask-2"])
    }

    @Test("Formula 与 Cask 各自独立限额 10 个")
    func eachCategoryIsCappedIndependently() async throws {
        let service = makeService(formulaCount: 15, caskCount: 15)
        let results = try await service.search(query: "tool")
        #expect(results.filter { !$0.isCask }.count == 10)
        #expect(results.filter { $0.isCask }.count == 10)
    }

    @Test("只有 Cask 匹配时仍返回 Cask")
    func caskOnlySearchReturnsCasks() async throws {
        let service = makeService(formulaCount: 0, caskCount: 4)
        let results = try await service.search(query: "app")
        #expect(results.filter { !$0.isCask }.isEmpty)
        #expect(results.filter { $0.isCask }.count == 4)
    }

    @Test("只有 Formula 匹配时仍返回 Formula")
    func formulaOnlySearchReturnsFormulae() async throws {
        let service = makeService(formulaCount: 12, caskCount: 0)
        let results = try await service.search(query: "lib")
        #expect(results.filter { !$0.isCask }.count == 10)
        #expect(results.filter { $0.isCask }.isEmpty)
    }

    // MARK: - Helpers

    /// 注入命令运行器：search 返回指定数量的名字，info 按请求的名字回显 JSON，
    /// 从而在不依赖真实 brew 的情况下精确锁定配额逻辑。
    private func makeService(formulaCount: Int, caskCount: Int) -> BrewService {
        let formulaNames = (0..<formulaCount).map { "formula-\($0)" }
        let caskNames = (0..<caskCount).map { "cask-\($0)" }
        return BrewService(brewPath: "/opt/homebrew/bin/brew", commandRunner: { _, arguments, _ in
            if arguments.first == "search" {
                let names = arguments.contains("--cask") ? caskNames : formulaNames
                return BrewCommandResult(exitCode: 0, stdout: names.joined(separator: "\n"), stderr: "")
            }
            let isCask = arguments.contains("--cask")
            let names = arguments.filter { $0 != "info" && $0 != "--json=v2" && $0 != "--cask" }
            let json: String
            if isCask {
                let entries = names.map { #"{"name":["\#($0)"],"token":"\#($0)","version":"1.0","installed":null}"# }
                json = #"{"formulae":[],"casks":[\#(entries.joined(separator: ","))]}"#
            } else {
                let entries = names.map { #"{"name":"\#($0)","versions":{"stable":"1.0"},"installed":[]}"# }
                json = #"{"formulae":[\#(entries.joined(separator: ","))],"casks":[]}"#
            }
            return BrewCommandResult(exitCode: 0, stdout: json, stderr: "")
        })
    }
}