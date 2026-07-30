import Foundation
import os
import SuperLogKit

/// FreeModel 供应商诊断日志（测试阶段开启，便于从 Xcode 控制台或 Console.app 复制）
enum FreeModelDiagnosticLog: SuperLog {
    static let verbose: Bool = true
    static let logger = Logger(subsystem: "com.coffic.lumi", category: "llm.freemodel")
}
