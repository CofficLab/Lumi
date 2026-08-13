import AppKit
import Combine
import KernelLumi
import SwiftUI

@MainActor
private final class MenuBarLogoObserver: ObservableObject {
    @Published private(set) var isHighlighted: Bool
    private var observation: AnyCancellable?

    init(logo: (any LogoProviding)?) {
        isHighlighted = logo?.isLogoHighlighted == true

        guard let logo else {
            MenuBarManagerPlugin.logger.error("[LogoHighlight] MenuBarLogoObserver: logo service is nil")
            return
        }

        let observable = logo as any ObservableObject
        let publisher = observable.objectWillChange as! ObservableObjectPublisher
        observation = publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let newValue = logo.isLogoHighlighted
                    guard self.isHighlighted != newValue else { return }
                    self.isHighlighted = newValue
                }
            }
    }
}

/// 状态栏最左侧的 Logo 视图:优先展示最高优先级插件 Logo,回退到应用图标。
struct MenuBarLogoView: View {
    let kernel: KernelLumi
    @StateObject private var logoObserver: MenuBarLogoObserver

    init(kernel: KernelLumi) {
        self.kernel = kernel
        _logoObserver = StateObject(wrappedValue: MenuBarLogoObserver(logo: kernel.logo))
    }

    private var isHighlighted: Bool {
        logoObserver.isHighlighted
    }

    private var logoItem: LogoItem? {
        kernel.logo?.highestPriorityLogoItem
    }

    private var logoView: AnyView? {
        let scene: LogoScene = kernel.logo?.isLogoHighlighted == true
            ? .statusBarHighlighted
            : .statusBar
        return logoItem?.makeView(scene)
    }

    var body: some View {
        Group {
            if let view = logoView {
                view
            } else {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .renderingMode(.template)
            }
        }
        .frame(width: 22, height: 22)
        .onAppear {
            let scene = isHighlighted ? "statusBarHighlighted" : "statusBar"
        }
    }
}
