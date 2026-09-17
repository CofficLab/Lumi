import Foundation
import FactoryLumi
import PluginACP
import ProviderACP

/// ACP headless 可执行入口（M2：握手验证）。
///
/// 目标：在无 NSApplication 环境下启动完整 Lumi 内核，以 ACP Agent
/// 身份通过 stdio 服务外部编辑器（或测试脚本）。
///
/// 运行：
///   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{}}}' \
///     | swift run --package-path Packages/ACPBootstrap
///
/// 协议外的诊断一律走 stderr，stdout 仅承载 ACP 帧。

let plugin = PluginACP()
plugin.onEOF = { exit(0) }

do {
    let kernel = try KernelFactory.makeKernel(additionalPlugins: [plugin])
    try plugin.startACPServer(transport: StdioTransport())
    // 进程常驻：等待 stdin 帧；EOF 后由 onEOF 退出。
    RunLoop.main.run()
} catch {
    fputs("ACP_BOOTSTRAP_FAILED \(error)\n", stderr)
    exit(1)
}
