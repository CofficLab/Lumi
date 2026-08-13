import KernelHosting
import KernelLumi
import SwiftUI

/// iOS 版 BookletMaker 组合门面。
///
/// 负责 BookletMaker iOS App 自己的内核组装与界面体系。
/// 它不与其他 iOS App 共享导航或布局抽象；真正跨平台共享的
/// 内核生命周期由 `KernelHosting` 提供。
@MainActor
public enum FactoryBookletMakerMobile {
    /// BookletMaker 插件 ID，启动后激活该容器。
    public static let bookletMakerPluginID = BookletMakerPluginCatalog.bookletMakerPluginID

    /// 组装并呈现 BookletMaker 主界面。
    public static func makeMainScene() -> some View {
        BookletMakerMobileHost()
    }
}

private struct BookletMakerMobileHost: View {
    @State private var kernel: KernelLumi?
    @State private var bootError: String?

    var body: some View {
        Group {
            if let kernel {
                BookletMakerMobileLayout(kernel: kernel)
            } else if let bootError {
                ContentUnavailableView {
                    Label("Unable to Open PDF Tools", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(bootError)
                } actions: {
                    Button("Try Again") { start() }
                }
            } else {
                ProgressView("Opening PDF Tools…")
            }
        }
        .task { start() }
    }

    private func start() {
        guard kernel == nil else { return }
        bootError = nil
        Task { @MainActor in
            do {
                let booted = try await KernelHosting.createKernel(
                    plugins: BookletMakerPluginCatalog.plugins,
                    enabledPluginIDs: [FactoryBookletMakerMobile.bookletMakerPluginID],
                    requiresAllCoreServices: false
                )
                booted.workspace?.activateContainer(
                    id: FactoryBookletMakerMobile.bookletMakerPluginID
                )
                kernel = booted
            } catch {
                bootError = error.localizedDescription
            }
        }
    }
}
