import Combine
import KernelCore
import ProviderLogo
import ProviderMenuBar
import SwiftUI

/// 状态栏图标区：Logo + 插件常驻小组件（网络速率、设备曲线等）。
///
/// `MenuBarExtra` 会把标签量成单行紧凑菜单项，裁掉插件的自定义视图；真实
/// `NSStatusItem` 保留其固有宽高，因此这两行内容留在状态栏本体而不是弹窗里。
/// 由宿主清单的 `HostStatusBarConfiguration.makeIconView` 交给共享状态栏宿主。
struct LumiStatusBarView: View {
    let logo: (any LogoProviding)?
    let menuBar: (any MenuBarProviding)?
    @StateObject private var refreshModel: ProviderRefreshModel

    init(kernel: KernelCoreContainer) {
        let logo = kernel.resolveProvider((any LogoProviding).self)
        let menuBar = kernel.resolveProvider((any MenuBarProviding).self)
        self.logo = logo
        self.menuBar = menuBar
        _refreshModel = StateObject(wrappedValue: ProviderRefreshModel(providers: [logo, menuBar]))
    }

    var body: some View {
        let _ = refreshModel.revision
        HStack(spacing: 4) {
            if let logo, let item = logo.highestPriorityLogoItem {
                let scene: LogoScene = logo.isLogoHighlighted ? .statusBarHighlighted : .statusBar
                item.makeView(scene)
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .frame(width: 20, height: 20)
            }

            if let menuBar {
                ForEach(menuBar.contentItems.sorted { $0.order < $1.order }) { item in
                    item.makeView()
                        .fixedSize(horizontal: true, vertical: true)
                        .help(item.title)
                }
            }
        }
        .padding(.horizontal, 2)
        .frame(height: 20)
    }
}

/// 把 Provider 自己的 `objectWillChange` 收敛到单个宿主视图。
///
/// Kernel 不转发 Provider 的高频状态变化，因此状态栏只随 Logo / MenuBar 刷新。
@MainActor
final class ProviderRefreshModel: ObservableObject {
    @Published private(set) var revision = 0
    private var subscriptions: [AnyCancellable] = []

    init(providers: [Any?]) {
        for provider in providers.compactMap({ $0 }) {
            guard let observable = provider as? any ObservableObject,
                  let publisher = observable.objectWillChange as? ObservableObjectPublisher
            else { continue }
            publisher.sink { [weak self] _ in
                self?.revision &+= 1
            }
            .store(in: &subscriptions)
        }
    }
}
