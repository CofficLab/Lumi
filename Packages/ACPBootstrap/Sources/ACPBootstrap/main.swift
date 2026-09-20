import Foundation
import FactoryLumiACP

/// ACP headless 可执行入口。
///
/// 目标：在无 NSApplication 环境下启动完整 Lumi 内核，以 ACP Agent
/// 身份通过 stdio 服务外部编辑器（或测试脚本）。
///
/// 运行：
///   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{}}}' \
///     | swift run --package-path Packages/ACPBootstrap
///
/// 协议外的诊断一律走 stderr，stdout 仅承载 ACP 帧。

do {
    try FactoryLumiACP.runACPServer()
} catch {
    fputs("ACP_BOOTSTRAP_FAILED \(error)\n", stderr)
    exit(1)
}
