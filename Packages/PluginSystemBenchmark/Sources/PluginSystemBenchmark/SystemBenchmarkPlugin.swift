import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderRailView
import ProviderRootView
import ProviderSettingView
import ProviderToolbar
import SwiftUI

@MainActor
public final class SystemBenchmarkPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.system-benchmark"
    public let order = 7
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.system-benchmark",
        name: BenchmarkLocalization.string("System Benchmark"),
        description: BenchmarkLocalization.string("Measure local CPU, memory, and disk performance."),
        category: .system,
        stage: .stable,
        policy: .disabledByDefault
    )

    private var viewModel: SystemBenchmarkViewModel?

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        let viewModel = SystemBenchmarkViewModel()
        self.viewModel = viewModel

        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: id,
                title: BenchmarkLocalization.string("System Benchmark"),
                systemImage: "gauge.with.dots.needle.67percent",
                order: order
            ) {
                SystemBenchmarkSettingsView(viewModel: viewModel)
            },
        ])

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: BenchmarkLocalization.string("System Benchmark"),
                    systemImage: "gauge.with.dots.needle.67percent",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        contentView?.setContentView(AnyView(SystemBenchmarkView(viewModel: viewModel)))
                        rootView?.setRailView(nil)
                        rootView?.setContentHeaderViewHidden(true)
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        rootView?.setRailView(railView?.makeRailView())
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        rootView?.setContentHeaderViewHidden(false)
                    }
                },
            ])
        } else {
            contentView?.setContentView(AnyView(SystemBenchmarkView(viewModel: viewModel)))
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        viewModel?.cancel()
        viewModel = nil
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [id])
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        activityBar?.removeItems(ids: ["\(id).entry"])

        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        rootView?.setRailView(railView?.makeRailView())
        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        rootView?.setContentHeaderViewHidden(false)
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }
    }
}
