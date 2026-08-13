import Foundation
import KernelLumi
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
    nonisolated static let verbose = false

    public init() {}

    /// 执行 boot
    public func execute(_ kernel: KernelLumi) async throws {
        if Self.verbose {
            Self.logger.info("\(Self.t)registering EditorService...")
        }

        let registry = EditorExtensionRegistry()
        let editorService = EditorService(editorExtensionRegistry: registry)
        try kernel.registerService(EditorService.self, editorService)

        // 创建文件树/编辑器协同器并注册到内核,供文件树等 UI 组件通过
        // `FileTreeEditorCoordination` 协议消费(无需直接依赖 EditorService)。
        let editorContext = EditorContext(service: editorService, kernel: kernel)
        try kernel.registerFileTreeEditorCoordination(editorContext)
        // 同一实例同时实现标签栏协同协议。
        try kernel.registerEditorTabStripCoordination(editorContext)

        if Self.verbose {
            Self.logger.info("\(Self.t)EditorService registered successfully")
        }
    }
}
