import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import SwiftUI

/// KernelCore 版本的 App Icon 设计器插件。
@MainActor
public final class AppIconDesignerPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.app-icon-designer"
    public let order = 79

    public static let railTabID = "app-icon-designer.documents"

    public var name: String {
        AppIconDesignerLocalization.string("AppIconDesigner Name")
    }

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        IconDesignerRuntime.configure(kernel: kernel, pluginID: id)

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)

        // 必须先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                groupID: id,
                title: AppIconDesignerLocalization.string("Icon Documents"),
                systemImage: "doc.text",
                order: order
            ) {
                AppIconDesignerRailView()
            },
        ])

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "app.dashed",
                    order: order
                ) { activeItemID in
                    guard activeItemID == entryID else { return }
                    IconDocumentStore.shared.reload()
                    contentView?.setContentView(AnyView(DesignerView()))
                    railView?.activateGroup(id: self.id)
                },
            ])
        } else {
            IconDocumentStore.shared.reload()
            contentView?.setContentView(AnyView(DesignerView()))
            railView?.activateGroup(id: id)
        }

        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { DesignerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { DesignerManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any RailViewProviding).self)?
            .removeTabs(ids: [Self.railTabID])

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        IconDesignerRuntime.reset()
    }
}
