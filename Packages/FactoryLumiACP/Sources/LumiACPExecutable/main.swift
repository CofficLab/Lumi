import FactoryLumiACP
import Foundation

setenv("LUMI_ACP_HEADLESS", "1", 1)

// 内核装配走 LumiFactory 的共享流水线，只能在主线程异步进行：先把启动任务投到
// 主队列，再让主 runloop 常驻——stdio 上的 JSON-RPC 事件正是由它驱动的。
Task { @MainActor in
    do {
        try await FactoryLumiACP.runACPServer()
    } catch {
        fputs("ACP_BOOTSTRAP_FAILED \(error)\n", stderr)
        exit(1)
    }
}

RunLoop.main.run()
