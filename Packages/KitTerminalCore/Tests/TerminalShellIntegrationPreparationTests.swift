import Foundation
import Testing
@testable import KitTerminalCore

/// 集成脚本工件的跨会话复用（见 issue #1234）。
///
/// 修复前每个会话启动都会在主线程删除并重建临时目录、重写全部注入脚本；
/// 脚本内容只由 shell 类型决定，与具体会话无关，因此首次校验/落盘后可以
/// 直接复用，后续启动只做极轻量的存在性检查，且全部发生在主线程之外。
@Suite("集成脚本工件复用")
struct TerminalShellIntegrationPreparationTests {

    @Test("首次准备产出全部脚本文件")
    func firstPreparationWritesAllArtifacts() async throws {
        let dir = try await ShellIntegration.prepareArtifacts(for: .zsh)
        #expect(dir == ShellIntegration.artifactsDirectory(for: .zsh))
        for artifact in ShellIntegration.expectedArtifacts(for: .zsh) {
            let content = try String(contentsOf: dir.appendingPathComponent(artifact.name), encoding: .utf8)
            #expect(content == artifact.content)
        }

        let bashDir = try await ShellIntegration.prepareArtifacts(for: .bash)
        for artifact in ShellIntegration.expectedArtifacts(for: .bash) {
            let content = try String(contentsOf: bashDir.appendingPathComponent(artifact.name), encoding: .utf8)
            #expect(content == artifact.content)
        }
    }

    @Test("再次准备复用已有文件，不重写脚本")
    func repeatedPreparationDoesNotRewriteFiles() async throws {
        let dir = try await ShellIntegration.prepareArtifacts(for: .zsh)
        let fileURL = dir.appendingPathComponent(".zshrc")
        let firstWriteDate = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date

        // 给文件系统时间推进，确保「若发生重写」修改时间必然变化。
        try await Task.sleep(nanoseconds: 50_000_000)
        let dirAgain = try await ShellIntegration.prepareArtifacts(for: .zsh)

        #expect(dirAgain == dir)
        let secondWriteDate = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        #expect(secondWriteDate == firstWriteDate, "复用路径不得重写已有脚本")
    }

    @Test("工件文件缺失时自动补齐")
    func missingArtifactIsRestored() async throws {
        let dir = try await ShellIntegration.prepareArtifacts(for: .zsh)
        let fileURL = dir.appendingPathComponent(".zlogin")
        try? FileManager.default.removeItem(at: fileURL)

        let dirAgain = try await ShellIntegration.prepareArtifacts(for: .zsh)

        #expect(dirAgain == dir)
        let restored = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(restored == ShellIntegration.expectedArtifacts(for: .zsh).first { $0.name == ".zlogin" }?.content)
    }

    @Test("跨进程的过时脚本内容在物化时被修复")
    func staleContentIsRepairedOnMaterialization() throws {
        // 直接调用物化路径，模拟「上一版本写入的脚本 + 本版本内容已变化」。
        let dir = ShellIntegration.artifactsDirectory(for: .bash)
        let fileURL = dir.appendingPathComponent("lumi_bash_integration.sh")
        try "#!/bin/bash\n# stale content from an older version\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let repaired = try ShellIntegration.materializeArtifacts(for: .bash)

        #expect(repaired == dir)
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content == ShellIntegration.expectedArtifacts(for: .bash).first?.content)
    }

    @Test("setupIntegration 组装环境与参数（回归 #346/#500）")
    func setupAssemblesEnvironmentAndArguments() async throws {
        let base = ShellIntegration.makeEnvironment(
            base: [], shellPath: "/bin/zsh", parentEnvironment: ["ZDOTDIR": "/tmp/custom-zsh"]
        )
        let zsh = try await ShellIntegration.setupIntegration(for: .zsh, baseEnvironment: base, useLogin: true)
        #expect(zsh.shellArguments.contains("-l"))
        #expect(zsh.shellArguments.contains("-i"))
        #expect(zsh.additionalEnvironment.contains("LUMI_INJECTION=1"))
        #expect(zsh.additionalEnvironment.contains("LUMI_SHELL_LOGIN=1"))
        #expect(zsh.additionalEnvironment.contains("USER_ZDOTDIR=/tmp/custom-zsh"))
        #expect(zsh.additionalEnvironment.contains {
            $0.hasPrefix("ZDOTDIR=") && $0 == "ZDOTDIR=\(ShellIntegration.artifactsDirectory(for: .zsh).path)"
        })

        let bash = try await ShellIntegration.setupIntegration(for: .bash, baseEnvironment: [], useLogin: true)
        #expect(bash.shellArguments.contains("--init-file"))
        #expect(bash.shellArguments.contains("-i"))
        #expect(!bash.shellArguments.contains("-l"))
    }
}
