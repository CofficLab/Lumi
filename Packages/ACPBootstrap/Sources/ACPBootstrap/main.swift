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

// 标记为 headless agent 进程：消费方（如自动标题）据此关闭针对 GUI 会话的
// 后台行为。必须在装配内核之前设置，插件 onBoot 时会读取。
setenv("LUMI_ACP_HEADLESS", "1", 1)

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
