import Foundation
import Testing
@testable import KitLumiCLI

/// #144 回归：从 shell 输出里挑 `PATH` 行时不能假设整行以 "/" 开头。
///
/// 合法 PATH 可能以相对条目（`.`、`foo`）或空条目开头，其后仍跟着绝对目录。
/// 旧实现用 `.last { $0.hasPrefix("/") }` 会把整行拒掉，导致登录 shell 里
/// 真正可写的安装目录丢失。这些测试直接驱动 `absolutePathEntries(fromShellOutput:)`，
/// 用构造的多行输出覆盖相对前缀、空条目、rc 噪声与尾随噪声。
@Suite("CLIPathResolver shell 输出")
struct CLIPathResolverShellOutputTests {

    @Test("以 . 开头的 PATH 行必须保留其后的绝对目录")
    func relativeDotPrefixKeepsAbsoluteEntries() {
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: ".:/custom/bin:/usr/bin")
        #expect(entries == ["/custom/bin", "/usr/bin"])
    }

    @Test("以相对目录开头的 PATH 行必须保留其后的绝对目录")
    func relativeDirectoryPrefixKeepsAbsoluteEntries() {
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: "bin:/custom/bin:/usr/bin")
        #expect(entries == ["/custom/bin", "/usr/bin"])
    }

    @Test("以空条目开头的 PATH 行必须保留其后的绝对目录")
    func emptyEntryPrefixKeepsAbsoluteEntries() {
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: ":/custom/bin:/usr/bin")
        #expect(entries == ["/custom/bin", "/usr/bin"])
    }

    @Test("PATH 前的 rc 噪声行被跳过，仍解析出绝对目录")
    func rcNoiseBeforePathIsSkipped() {
        let output = "Welcome to zsh\n/etc/motd line\n.:/custom/bin:/usr/bin"
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: output)
        #expect(entries == ["/custom/bin", "/usr/bin"])
    }

    @Test("全绝对 PATH 行解析保持不变（无回归）")
    func absoluteOnlyPathUnchanged() {
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: "/usr/bin:/bin")
        #expect(entries == ["/usr/bin", "/bin"])
    }

    @Test("全相对 PATH 行不产生绝对条目")
    func allRelativePathYieldsEmpty() {
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: ".:./bin:foo")
        #expect(entries.isEmpty)
    }

    @Test("PATH 后的尾随噪声行被跳过")
    func trailingNoiseAfterPathIsSkipped() {
        let output = "/usr/bin:/bin\nsome trailing log"
        let entries = CLIPathResolver.absolutePathEntries(fromShellOutput: output)
        #expect(entries == ["/usr/bin", "/bin"])
    }

    @Test("空输出得到空列表")
    func emptyOutputYieldsEmpty() {
        #expect(CLIPathResolver.absolutePathEntries(fromShellOutput: "").isEmpty)
    }
}
