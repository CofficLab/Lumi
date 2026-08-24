import CADDesignerPlugin
import KernelCore
import ProviderContentView
import SwiftUI

/// CAD 编辑器的 KernelCore 入口。
///
/// 先复用经过验证的 CAD 文档、渲染与编辑视图；后续工具迁移将替换其
/// 旧 `LumiAgentTool` 适配层，而不改变 CAD 文件格式或编辑体验。
@MainActor
public final class CADDesignerSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.cad-designer"
    public let order = 80
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.cad-designer",
        name: "CAD Designer",
        description: "Aluminum profile CAD design workspace.",
        category: .design,
        stage: .preview,
        policy: .disabledByDefault
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?
            .setContentView(AnyView(CADDesignerView()))
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
    }
}
