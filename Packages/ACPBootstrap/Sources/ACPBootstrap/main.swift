import Foundation
import FactoryLumi
import KernelCore
import ProviderACP
import ProviderAgentLoop
import ProviderConversation
import ProviderToolManager

/// ACP headless 冒烟测试入口（M2 验证 R1）。
///
/// 目标：验证 `KernelFactory.makeKernel()` 在**无 NSApplication（GUI）** 环境下
/// 能否安全启动完整插件目录，并 resolve 出 agent 所需的核心 Provider。
///
/// 运行：`swift run --package-path Packages/ACPBootstrap`
/// 期望输出：`ACP_BOOTSTRAP_OK` 前缀；任何异常以 `ACP_BOOTSTRAP_FAILED` 退出码 1 退出。
///
/// 注意：本进程不创建 NSApplication、不装配任何 SwiftUI 视图。

private enum SmokeFailure: Error, CustomStringConvertible {
    case missingProvider(String)
    case unexpected(Error)

    var description: String {
        switch self {
        case .missingProvider(let name):
            return "缺少核心 Provider：\(name)"
        case .unexpected(let error):
            return "非预期错误：\(error)"
        }
    }
}

do {
    // KernelFactory.makeKernel() 为 @MainActor；Swift 顶层代码默认运行在 MainActor，
    // 因此这里无需额外包装。
    let kernel = try KernelFactory.makeKernel()

    // 1. Agent 回合循环
    guard let agentLoop = kernel.resolveProvider((any AgentLoopProviding).self) else {
        throw SmokeFailure.missingProvider("AgentLoopProviding")
    }
    // 2. 会话/对话管理
    guard let conversations = kernel.resolveProvider((any ConversationManaging).self) else {
        throw SmokeFailure.missingProvider("ConversationManaging")
    }
    // 3. 工具系统
    guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
        throw SmokeFailure.missingProvider("ToolManagerProviding")
    }

    let toolCount = toolManager.allTools().count
    let conversationCount = conversations.conversations.count

    print("ACP_BOOTSTRAP_OK agentLoop=\(type(of: agentLoop))")
    print("ACP_BOOTSTRAP_OK conversations=\(conversationCount) tools=\(toolCount)")

    if toolCount == 0 {
        print("ACP_BOOTSTRAP_WARN 工具数量为 0：headless 下可能缺少工具注册")
    }
} catch {
    print("ACP_BOOTSTRAP_FAILED \(error)")
    exit(1)
}
