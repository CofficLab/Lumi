import Foundation
import Testing
@testable import KitLumiCLI

/// `CLIPathResolver` 的 `PATH` 解析测试。
@Suite("CLIPathResolver")
struct CLIPathResolverTests {

    @Test("PATH 字符串按冒号拆分并去掉空项")
    func parsesPathEntries() {
        let entries = CLIPathResolver.parsePathEntries("/usr/bin::/bin:/usr/sbin:")
        #expect(entries == ["/usr/bin", "/bin", "/usr/sbin"])
    }

    @Test("空 PATH 得到空列表")
    func parsesEmptyPath() {
        #expect(CLIPathResolver.parsePathEntries("").isEmpty)
    }

    @Test("解析出的用户 PATH 包含系统目录")
    func resolvedPathContainsSystemDirectories() {
        let entries = CLIPathResolver.resolveUserPath()
        #expect(entries.contains("/usr/bin"))
    }

    @Test("解析用户 PATH 优先于进程 PATH")
    func resolvedPathPrefersUserShellPath() {
        // GUI 启动的 App 只继承系统最小 PATH；解析用户 shell 的 PATH 才能
        // 看到 Homebrew、~/.local/bin 等用户目录。
        //
        // 不比较条目数量：用户 shell 的 PATH 与进程 PATH 谁更长完全取决于
        // 机器环境（CI agent 往往会注入一条很长的进程 PATH），无法作为契约。
        // 改为给进程 PATH 注入一个哨兵目录，断言解析结果不来自进程 PATH 兜底，
        // 从而确定性地验证「优先使用 shell PATH」这一行为。
        let sentinel = "/__lumi_cli_process_path_sentinel__"
        let shell = launchShellPathForTest()
        let entries = CLIPathResolver.resolveUserPath(
            environment: ["SHELL": shell, "PATH": sentinel]
        )

        #expect(!entries.isEmpty)
        #expect(!entries.contains(sentinel))
    }

    /// 选一个存在的 shell 供 PATH 解析测试使用；找不到时返回无效路径，
    /// 让被测方法走进程 PATH 兜底（此时哨兵会出现，测试会如实失败）。
    private func launchShellPathForTest() -> String {
        for candidate in [ProcessInfo.processInfo.environment["SHELL"], "/bin/zsh", "/bin/bash"]
            .compactMap({ $0 }) {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return "/nonexistent/shell"
    }

    @Test("SHELL 无效时回落到进程 PATH")
    func fallsBackToProcessPathWithInvalidShell() {
        let entries = CLIPathResolver.resolveUserPath(
            environment: ["SHELL": "/nonexistent/shell", "PATH": "/usr/bin:/bin"]
        )

        // 无效 shell 时仍应拿到可用条目（来自进程 PATH 兜底）。
        #expect(!entries.isEmpty)
    }

    @Test("shell 解析不会挂起")
    func resolutionTerminatesPromptly() {
        // 交互式 shell 加载 rc 可能很慢，解析必须有界。
        let start = Date()
        _ = CLIPathResolver.resolveUserPath()
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 10, "PATH 解析耗时 \(elapsed)s，超出预期")
    }
}
