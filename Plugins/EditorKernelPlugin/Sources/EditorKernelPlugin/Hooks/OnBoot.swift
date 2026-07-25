import Foundation
import LumiKernel
import EditorService
import SuperLogKit
import os

/// EditorKernel 插件 OnBoot 阶段钩子
///
/// 负责 boot 阶段的编辑器核心装配:
/// 1. 创建 `EditorExtensionRegistry`(扩展点注册表)。
/// 2. 用其初始化 `EditorService`(编辑器子系统唯一门面)。
/// 3. 以**具象类型** `EditorService.self` 注册到内核。
///
/// 这里注册的是具象门面实例,供 UI 层(`EditorPanelPlugin` 等)
/// 通过 `kernel.resolveService(EditorService.self)` 取用并注入 `@EnvironmentObject`。
/// 文件/主题能力契约(`EditorProviding`)由 `EditorProviderPlugin` 单独负责。
@MainActor
public struct EditorKernelOnBootHook: SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.editor-kernel")
    nonisolated static let verbose = true

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: LumiKernel) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)registering EditorService...")
        }

        let registry = EditorExtensionRegistry()
        let editorService = EditorService(editorExtensionRegistry: registry)
        kernel.registerService(EditorService.self, editorService)

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorService registered successfully")
        }
    }
}
