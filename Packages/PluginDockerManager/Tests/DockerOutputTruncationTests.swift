import Testing
import KitShell
@testable import DockerManagerPlugin

// 回归 #258：docker images / history / trivy 输出超过 KitShell 捕获上限时只保留尾部，
// 必须显式报 outputTruncated，不能把截尾当完整列表/报告而静默丢镜像或漏报漏洞。
@Suite("Docker 输出截断")
struct DockerOutputTruncationTests {

    @Test("退出码 0 但 stdout 被截断时抛 outputTruncated")
    func commandOutputThrowsWhenTruncated() {
        let result = ShellResult(exitCode: 0, stdout: "{\"ID\":\"sha256:tail\"}", stderr: "", stdoutTruncated: true)
        do {
            _ = try DockerService.interpretCommandOutput(result)
            Issue.record("expected outputTruncated")
        } catch DockerError.outputTruncated {
            #expect(DockerError.outputTruncated.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("退出码 0 且未截断时原样返回 stdout")
    func commandOutputReturnsStdoutWhenComplete() throws {
        let result = ShellResult(exitCode: 0, stdout: "complete output", stderr: "", stdoutTruncated: false)
        let output = try DockerService.interpretCommandOutput(result)
        #expect(output == "complete output")
    }

    @Test("非零退出抛 commandFailed 并透传 stderr")
    func commandOutputThrowsCommandFailedOnNonZeroExit() {
        let result = ShellResult(exitCode: 1, stdout: "", stderr: "boom", stdoutTruncated: false)
        do {
            _ = try DockerService.interpretCommandOutput(result)
            Issue.record("expected commandFailed")
        } catch DockerError.commandFailed(let message) {
            #expect(message == "boom")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }

    @Test("非零退出且 stderr 为空时回退到 stdout")
    func commandFailedFallsBackToStdoutWhenStderrEmpty() {
        let result = ShellResult(exitCode: 2, stdout: "out message", stderr: "", stdoutTruncated: false)
        do {
            _ = try DockerService.interpretCommandOutput(result)
            Issue.record("expected commandFailed")
        } catch DockerError.commandFailed(let message) {
            #expect(message == "out message")
        } catch {
            Issue.record("unexpected error: \(error)")
        }
    }
}