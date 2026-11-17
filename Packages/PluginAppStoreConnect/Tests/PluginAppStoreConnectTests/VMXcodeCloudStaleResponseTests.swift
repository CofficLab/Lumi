import Foundation
import Testing
@testable import PluginAppStoreConnect

/// 回归覆盖 issue #434：Xcode Cloud 视图的加载链路曾在 await 之后无条件把
/// 响应写入 VM 状态。加载工作流/详情/构建期间切换产品或工作流时，迟到的
/// 响应会覆盖新选中项的数据，出现「点 A 工作流却显示 B 的构建」。
///
/// 修复后响应落盘走 `applyCiWorkflowsResponse` / `applyCiWorkflowDetailResponse`
/// / `applyCiBuildRunsResponse`：只有选中的产品/工作流仍是发起请求时的那个，
/// 响应才会写入；否则丢弃。
@Suite(.serialized)
struct VMXcodeCloudStaleResponseTests {

    @MainActor
    private func makeViewModel() -> VM {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VMXcodeCloudStaleResponseTests-\(UUID().uuidString)", isDirectory: true)
        return VM(localStore: AppStoreConnectPluginLocalStore(pluginDirectory: directory))
    }

    @MainActor
    private func makeProduct(id: String) -> CiProduct {
        CiProduct(id: id, name: "Product \(id)", productType: "APP", bundleID: "com.example.\(id)")
    }

    @MainActor
    private func makeWorkflow(id: String) -> CiWorkflow {
        CiWorkflow(
            id: id,
            name: "Workflow \(id)",
            description: "",
            isEnabled: true,
            clean: false,
            containerFilePath: "project.yml",
            platformType: "macOS"
        )
    }

    @MainActor
    private func makeBuildRun(id: String, number: Int) -> CiBuildRun {
        CiBuildRun(id: id, number: number, executionProgress: "COMPLETE", completionStatus: "SUCCEEDED")
    }

    /// 工作流列表响应到达前切换了产品：迟到响应不得写入，也不得改动新选中的工作流。
    @Test("迟到的产品工作流列表不覆盖已切换的产品（回归 #434）")
    @MainActor
    func staleWorkflowListDoesNotClobberSwitchedProduct() {
        let viewModel = makeViewModel()
        viewModel.selectedCiProduct = makeProduct(id: "prod-a")

        // 列表 pending 期间切到另一个产品。
        viewModel.selectedCiProduct = makeProduct(id: "prod-b")

        let applied = viewModel.applyCiWorkflowsResponse(
            [makeWorkflow(id: "wf-a1"), makeWorkflow(id: "wf-a2")],
            forProductID: "prod-a"
        )

        #expect(!applied)
        #expect(viewModel.ciWorkflows.isEmpty)
        #expect(viewModel.selectedCiWorkflow == nil)
        #expect(viewModel.selectedCiWorkflowDetail == nil)
        #expect(viewModel.ciBuildRuns.isEmpty)
    }

    /// 工作流列表响应仍属于当前产品：写入列表并自动选中第一条。
    @Test("当前产品的工作流列表正常写入并选中第一条（回归 #434）")
    @MainActor
    func currentWorkflowListAppliesAndSelectsFirst() {
        let viewModel = makeViewModel()
        viewModel.selectedCiProduct = makeProduct(id: "prod-a")

        let applied = viewModel.applyCiWorkflowsResponse(
            [makeWorkflow(id: "wf-a1"), makeWorkflow(id: "wf-a2")],
            forProductID: "prod-a"
        )

        #expect(applied)
        #expect(viewModel.ciWorkflows.map(\.id) == ["wf-a1", "wf-a2"])
        #expect(viewModel.selectedCiWorkflow?.id == "wf-a1")
    }

    /// 工作流详情响应到达前切换了工作流：迟到的详情不得写入。
    @Test("迟到的工作流详情不覆盖已切换的工作流（回归 #434）")
    @MainActor
    func staleWorkflowDetailDoesNotClobberSwitchedWorkflow() {
        let viewModel = makeViewModel()
        viewModel.selectedCiProduct = makeProduct(id: "prod-a")
        viewModel.ciWorkflows = [makeWorkflow(id: "wf-a"), makeWorkflow(id: "wf-b")]
        viewModel.selectedCiWorkflow = viewModel.ciWorkflows[0]

        // 详情 pending 期间切到另一条工作流。
        viewModel.selectedCiWorkflow = viewModel.ciWorkflows[1]

        let staleDetail = CiWorkflow(id: "wf-a", name: "Workflow wf-a RENAMED")
        let applied = viewModel.applyCiWorkflowDetailResponse(staleDetail, forWorkflowID: "wf-a")

        #expect(!applied)
        #expect(viewModel.selectedCiWorkflowDetail == nil)
        #expect(viewModel.selectedCiWorkflow?.id == "wf-b")
    }

    /// 构建列表响应到达前切换了工作流：迟到的构建不得覆盖新工作流的空构建列表。
    @Test("迟到的构建列表不覆盖已切换的工作流（回归 #434）")
    @MainActor
    func staleBuildRunsDoNotClobberSwitchedWorkflow() {
        let viewModel = makeViewModel()
        viewModel.selectedCiProduct = makeProduct(id: "prod-a")
        viewModel.ciWorkflows = [makeWorkflow(id: "wf-a"), makeWorkflow(id: "wf-b")]
        viewModel.selectedCiWorkflow = viewModel.ciWorkflows[0]

        // 构建 pending 期间切到另一条工作流。
        viewModel.selectedCiWorkflow = viewModel.ciWorkflows[1]

        let applied = viewModel.applyCiBuildRunsResponse(
            [makeBuildRun(id: "run-a1", number: 1), makeBuildRun(id: "run-a2", number: 2)],
            forWorkflowID: "wf-a"
        )

        #expect(!applied)
        #expect(viewModel.ciBuildRuns.isEmpty)
    }

    /// 当前工作流的构建列表正常写入。
    @Test("当前工作流的构建列表正常写入（回归 #434）")
    @MainActor
    func currentBuildRunsApply() {
        let viewModel = makeViewModel()
        viewModel.selectedCiProduct = makeProduct(id: "prod-a")
        viewModel.ciWorkflows = [makeWorkflow(id: "wf-a")]
        viewModel.selectedCiWorkflow = viewModel.ciWorkflows[0]

        let applied = viewModel.applyCiBuildRunsResponse(
            [makeBuildRun(id: "run-a1", number: 1)],
            forWorkflowID: "wf-a"
        )

        #expect(applied)
        #expect(viewModel.ciBuildRuns.map(\.id) == ["run-a1"])
    }

    /// 工作流列表为空时清空详情与构建，避免残留上一条工作流的数据。
    @Test("空工作流列表清空详情与构建（回归 #434）")
    @MainActor
    func emptyWorkflowListClearsSelection() {
        let viewModel = makeViewModel()
        viewModel.selectedCiProduct = makeProduct(id: "prod-a")
        viewModel.ciWorkflows = [makeWorkflow(id: "wf-a")]
        viewModel.selectedCiWorkflow = viewModel.ciWorkflows[0]
        viewModel.selectedCiWorkflowDetail = makeWorkflow(id: "wf-a")
        viewModel.ciBuildRuns = [makeBuildRun(id: "run-a1", number: 1)]

        let applied = viewModel.applyCiWorkflowsResponse([], forProductID: "prod-a")

        #expect(applied)
        #expect(viewModel.ciWorkflows.isEmpty)
        #expect(viewModel.selectedCiWorkflow == nil)
        #expect(viewModel.selectedCiWorkflowDetail == nil)
        #expect(viewModel.ciBuildRuns.isEmpty)
    }
}
