import KitAgentTool
import Testing
@testable import PluginAppStoreConnect

/// 工具失败必须以抛出表达。
///
/// 此前 `Missing or empty ...` / `Missing or invalid ...` / `Failed to ...`
/// 都通过字符串返回，默认 `executeResult` 会把它们包成 `isError == false`
/// 的成功结果，于是失败的 App Store Connect 调用被记成 completed。
@Suite("App Store Connect 工具失败语义")
struct ToolFailureSemanticsTests {
    private func expectThrows<T: SuperAgentTool>(
        _ tool: T,
        _ arguments: [String: ToolArgument] = [:]
    ) async {
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(arguments: arguments)
        }
    }

    @Test("缺少必填参数时抛出 ToolExecutionError")
    func missingRequiredArgumentsThrow() async {
        await expectThrows(ListAppStoreConnectVersionsTool())
        await expectThrows(ListAppStoreConnectBuildsTool())
        await expectThrows(ReadAppStoreConnectVersionTool())
        await expectThrows(ReadAppStoreConnectLocalizationTool())
        await expectThrows(ListAppStoreConnectScreenshotsTool())
        await expectThrows(CreateAppStoreConnectScreenshotSetTool())
        await expectThrows(UploadAppStoreConnectScreenshotTool())
        await expectThrows(WithdrawAppStoreConnectSubmissionTool())
        await expectThrows(CreateAppStoreConnectVersionTool())
        await expectThrows(CreateAppStoreConnectLocalizationTool())
        await expectThrows(UpdateAppStoreConnectLocalizationTool())
        await expectThrows(DeleteAppStoreConnectScreenshotTool())
        await expectThrows(DeleteAppStoreConnectVersionTool())
        await expectThrows(ReleaseAppStoreConnectVersionTool())
        await expectThrows(AssignAppStoreConnectBuildTool())
        await expectThrows(ListAppStoreConnectScreenshotSetsTool())
        await expectThrows(ListAppStoreConnectLocalizationsTool())
        await expectThrows(ListAppStoreConnectCiWorkflowsTool())
        await expectThrows(ListAppStoreConnectCiBuildRunsTool())
        await expectThrows(ReadAppStoreConnectCiWorkflowTool())
        await expectThrows(StartAppStoreConnectCiBuildRunTool())
        await expectThrows(SubmitAppStoreConnectVersionTool())
    }

    @Test("空白参数等同于缺失，同样抛出")
    func blankArgumentsThrow() async {
        await expectThrows(ListAppStoreConnectVersionsTool(), ["appID": ToolArgument("   ")])
        await expectThrows(ReadAppStoreConnectVersionTool(), ["versionID": ToolArgument("\n")])
    }

    @Test("isEnabled 非法时抛出而不是退回默认值")
    func invalidIsEnabledThrows() async {
        await expectThrows(
            SetAppStoreConnectCiWorkflowEnabledTool(),
            ["workflowID": ToolArgument("workflow-1"), "isEnabled": ToolArgument("maybe")]
        )
    }
}
