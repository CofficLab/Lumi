import Foundation
import FactoryACP
import KernelCore
import PluginACP
import ProviderACP

// Headless ACP agent 入口（Xcode app target 版）。
// 与 ACPBootstrap main.swift 逻辑一致：组装内核 → 启动 stdio server → RunLoop 常驻。

setenv("LUMI_ACP_HEADLESS", "1", 1)

do {
    let kernel = try FactoryACP.makeKernel()

    guard let plugin = kernel.resolvePlugin(id: "acp") as? PluginACP else {
        fputs("ACP_BOOTSTRAP_FAILED plugin 'acp' not found\n", stderr)
        exit(1)
    }

    plugin.onEOF = { exit(0) }
    try plugin.startACPServer(transport: StdioTransport())

    RunLoop.main.run()
} catch {
    fputs("ACP_BOOTSTRAP_FAILED \(error)\n", stderr)
    exit(1)
}
