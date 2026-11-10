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
        let entries = CLIPathResolver.resolveUserPath()
        #expect(!entries.isEmpty)

        // 用户目录存在时应当被解析出来（存在性取决于开发机环境，
        // 因此只断言「解析成功且不短于系统 PATH」）。
        let systemEntries = CLIPathResolver.parsePathEntries(
            ProcessInfo.processInfo.environment["PATH"] ?? ""
        )
        #expect(entries.count >= systemEntries.count)
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
