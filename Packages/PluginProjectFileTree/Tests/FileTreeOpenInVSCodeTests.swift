import Foundation
import Testing

@testable import PluginProjectFileTree

/// 回归 #1105：`/usr/bin/env code` 能 launch 不代表 `code` 存在。
/// 旧实现只 catch `process.run()`，env 随后以非零状态退出时 fallback 不执行，
/// 用户也得不到反馈。现在必须检查退出状态并在失败时回退到 VS Code 应用。
@MainActor
struct FileTreeOpenInVSCodeTests {

    @Test("code 命令非零退出时回退到应用打开")
    func nonZeroCodeStatusFallsBackToApplication() async {
        var fallbackUsed = false
        let opened = await FileTreeFacade.resolveVSCodeOpen(commandStatus: 127) {
            fallbackUsed = true
            return true
        }

        #expect(opened)
        #expect(fallbackUsed)
    }

    @Test("code 命令无法启动时回退到应用打开")
    func unlaunchableCommandFallsBackToApplication() async {
        var fallbackUsed = false
        let opened = await FileTreeFacade.resolveVSCodeOpen(commandStatus: nil) {
            fallbackUsed = true
            return true
        }

        #expect(opened)
        #expect(fallbackUsed)
    }

    @Test("code 命令成功退出时不再回退到应用")
    func successfulCodeCommandSkipsApplicationFallback() async {
        var fallbackUsed = false
        let opened = await FileTreeFacade.resolveVSCodeOpen(commandStatus: 0) {
            fallbackUsed = true
            return true
        }

        #expect(opened)
        #expect(!fallbackUsed)
    }

    @Test("应用回退也失败时报告打开失败")
    func applicationFallbackFailureReportsFailure() async {
        let opened = await FileTreeFacade.resolveVSCodeOpen(commandStatus: 127) {
            false
        }

        #expect(!opened)
    }

    @Test("code 命令缺失时外部进程的退出状态非零")
    func missingCommandExitStatusIsObserved() {
        let status = FileTreeFacade.runAndWait(
            executable: "/usr/bin/env",
            arguments: ["lumi-missing-command-\(UUID().uuidString)"]
        )

        #expect(status != nil)
        #expect(status != 0)
    }
}
