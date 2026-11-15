import Testing
import Foundation
@testable import BrewManagerPlugin

/// 回归 #408：BrewService 用 KitShell 默认 64 KiB 输出上限，`brew info --json=v2`
/// 的大 JSON 被截成尾部后，exitCode 仍是 0，旧实现直接把残缺尾部交给 JSONDecoder，
/// 于是正常的大响应必然解析失败。修复后：上限提到 16 MiB 容纳完整文档，且一旦
/// stdout 仍被截断，execute 必须抛 outputTruncated，绝不能把尾部当成功解析。
struct BrewOutputTruncationTests {

    // MARK: - 截断判定（注入命令运行器）

    @Test("listInstalled 遇到截断的 stdout 必须抛 outputTruncated")
    func listInstalledThrowsWhenStdoutTruncated() async {
        let service = makeService(
            BrewCommandResult(exitCode: 0, stdout: #"{"formulae":[{"name":"#, stderr: "", stdoutTruncated: true)
        )
        await #expect {
            _ = try await service.listInstalled()
        } throws: { error in
            guard case .outputTruncated = error as? BrewError else { return false }
            return true
        }
    }

    @Test("getInfo 遇到截断的 stdout 必须抛 outputTruncated")
    func getInfoThrowsWhenStdoutTruncated() async {
        let service = makeService(
            BrewCommandResult(exitCode: 0, stdout: #"{"formulae":[{"name":"#, stderr: "", stdoutTruncated: true)
        )
        await #expect {
            _ = try await service.getInfo(names: ["foo"], isCask: false)
        } throws: { error in
            guard case .outputTruncated = error as? BrewError else { return false }
            return true
        }
    }

    @Test("未截断的完整 JSON 仍正常解析")
    func listInstalledParsesCompleteJSONWhenNotTruncated() async throws {
        let json = #"{"formulae":[{"name":"foo","versions":{"stable":"1.0"},"installed":[{"version":"1.0"}]}],"casks":[]}"#
        let service = makeService(
            BrewCommandResult(exitCode: 0, stdout: json, stderr: "", stdoutTruncated: false)
        )
        let packages = try await service.listInstalled()
        #expect(packages.count == 1)
        #expect(packages.first?.name == "foo")
    }

    @Test("非零退出码优先报 commandFailed，而不是截断错误")
    func nonZeroExitWithTruncationThrowsCommandFailed() async {
        let service = makeService(
            BrewCommandResult(exitCode: 1, stdout: "tail", stderr: "boom", stdoutTruncated: true)
        )
        await #expect {
            _ = try await service.listInstalled()
        } throws: { error in
            guard case .commandFailed = error as? BrewError else { return false }
            return true
        }
    }

    @Test("outputTruncated 暴露错误描述")
    func outputTruncatedErrorHasDescription() {
        #expect(BrewError.outputTruncated.errorDescription?.contains("truncated") == true)
    }

    // MARK: - 真实 shell 输出上限与截断标志

    @Test("runBrewCommand 保留超过旧 64 KiB 上限的完整输出")
    func runBrewCommandRetainsOutputAboveLegacyLimit() async throws {
        // 200 KiB 远超旧的 64 KiB 默认上限，但小于新的 16 MiB；必须完整保留且不标记截断。
        // 用 /dev/zero→tr 生成纯 'A'（无尾随空白），避免 KitShell 的 trailing trim 改变字节数。
        let byteCount = 200 * 1024
        let result = try await BrewService.runBrewCommand(
            executable: "/bin/sh",
            arguments: ["-c", "head -c \(byteCount) /dev/zero | tr '\\0' 'A'"],
            environment: [:]
        )
        #expect(result.exitCode == 0)
        #expect(!result.stdoutTruncated)
        #expect(result.stdout.utf8.count == byteCount)
    }

    @Test("runBrewCommand 对超过新上限的输出标记截断")
    func runBrewCommandFlagsTruncationAboveLimit() async throws {
        let overLimit = BrewService.maxOutputBytes + 1024
        let result = try await BrewService.runBrewCommand(
            executable: "/bin/sh",
            arguments: ["-c", "head -c \(overLimit) /dev/zero | tr '\\0' 'A'"],
            environment: [:]
        )
        #expect(result.stdoutTruncated)
    }

    // MARK: - Helpers

    private func makeService(_ result: BrewCommandResult) -> BrewService {
        BrewService(brewPath: "/opt/homebrew/bin/brew", commandRunner: { _, _, _ in result })
    }
}