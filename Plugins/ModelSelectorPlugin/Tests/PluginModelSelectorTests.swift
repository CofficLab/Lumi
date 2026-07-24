import Foundation
import LumiKernel
import Testing
@testable import ModelSelectorPlugin

// 注:Agent tools 的端到端测试需要 `ChatKernelPlugin` 的内部 API
// (`ChatService(configuration: .coreDatabase(...))`),跨模块不可见。
// 真正的端到端测试由 ChatKernelPlugin 自己提供。
// 这里只保留纯类型 / 配置测试。
