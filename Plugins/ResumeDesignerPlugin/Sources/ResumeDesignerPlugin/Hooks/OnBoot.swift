import Foundation
import KernelLumi
import os

/// ResumeDesigner 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的所有初始化逻辑：
/// - 配置 Runtime（注入 kernel 引用）
/// - 重新加载工作区简历列表
@MainActor
public struct ResumeDesignerOnBootHook {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.resume-designer")

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: KernelLumi) async throws {
        Runtime.configure(kernel: kernel)
        WorkspaceStore.shared.reload()
    }
}
