import Foundation
import KitAgentTool
import Testing
@testable import PluginAppStoreConnect

/// 回归 #861：没有真正执行的调用必须以失败表达。
///
/// 参数校验之后、真正的远端调用之前的那些分支（文件不存在、没有待撤回的
/// 提交、没有可更新的字段、年龄分级声明不存在）此前都用普通文本返回，
/// 默认的 `executeResult` 会把它们包成 `isError == false` 的成功结果。
///
/// 这些测试覆盖「客户端不可用」之前的路径：参数或前置条件不满足时，
/// 失败原因必须是参数本身，而不是被「凭据缺失」掩盖。
@MainActor
@Suite("App Store Connect 工具的前置条件失败")
struct ToolPreconditionFailureTests {

    @Test("上传截图时文件不存在属于失败")
    func uploadScreenshotRequiresExistingFile() async {
        let tool = UploadAppStoreConnectScreenshotTool()

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(arguments: [
                "screenshotSetID": ToolArgument("set-1"),
                "filePath": ToolArgument("/tmp/lumi-definitely-missing-screenshot.png"),
            ])
        }
    }

    @Test("更新版本时没有任何可更新字段属于失败")
    func updateVersionRequiresAtLeastOneField() async {
        let tool = UpdateAppStoreConnectVersionTool()

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(arguments: [
                "versionID": ToolArgument("version-1"),
            ])
        }
    }

    @Test("更新本地化时没有任何可更新字段属于失败")
    func updateLocalizationRequiresAtLeastOneField() async {
        let tool = UpdateAppStoreConnectLocalizationTool()

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(arguments: [
                "localizationID": ToolArgument("localization-1"),
            ])
        }
    }

    @Test("前置条件失败的原因不是「凭据缺失」")
    func preconditionFailureIsNotMaskedByCredentialError() async {
        let tool = UpdateAppStoreConnectVersionTool()

        do {
            _ = try await tool.executeResult(arguments: [
                "versionID": ToolArgument("version-1"),
            ])
            Issue.record("Expected the tool to reject a call without update fields")
        } catch let error as ToolExecutionError {
            let reason = error.localizedDescription
            #expect(reason.contains("copyright"))
            #expect(!reason.contains("credential"))
            #expect(!reason.contains("Network service"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}
