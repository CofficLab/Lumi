import CADDesignerPlugin
import KernelCore
import ProviderContentView
import ProviderDocsView
import ProviderToolbar
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
        kernel.resolveProvider((any ToolbarProviding).self)?.addToolbarItems([
            ToolbarItem(id: "\(id).title", title: metadata.name, placement: .center, order: 0) {
                Text(self.metadata.name).font(.headline)
            },
        ])
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { CADDesignerAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { CADDesignerManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).title"])
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
