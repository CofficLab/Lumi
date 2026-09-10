import KernelCore
import ProviderAppUpdate
import ProviderNetwork

/// Lumi distribution-level update bootstrap.
///
/// Sparkle is deliberately host-owned rather than registered in
/// `FactoryLumi`'s generic plugin catalog: App Store builds must not link an
/// in-app updater. The Lumi host invokes this once after its V2 kernel has
/// registered `NetworkProviding`, preserving the old plugin's boot behavior.
@MainActor
public enum AppUpdateBootstrap {
    private static var requestObserver: UpdateRequestObserver?
    private static weak var registeredKernel: KernelCoreContainer?

    public static func start(kernel: KernelCoreContainer) {
        let service = UpdateService.shared
        // This is a host-owned provider: the updater is intentionally not
        // part of the generic plugin catalog, but settings can still use the
        // typed contract without importing Sparkle. Register it even for Debug
        // builds; Debug keeps update checks disabled, but the channel setting
        // should remain visible and testable in an Xcode-built app.
        if registeredKernel !== kernel {
            registeredKernel?.unregisterProvider((any AppUpdateChannelProviding).self)
            try? kernel.registerHostProvider((any AppUpdateChannelProviding).self, service)
            registeredKernel = kernel
        }
        requestObserver?.cancel()
        requestObserver = UpdateRequestObserver(
            onCheckForUpdates: { [weak service] in service?.checkForUpdates() },
            onInstallPreparedUpdate: { [weak service] in service?.handleInstallPreparedAppUpdateRequest() }
        )
        if let network = kernel.resolveProvider((any NetworkProviding).self) {
            service.configure(network: network)
        }
        service.setupFeedURLIfNeeded()
    }

    public static func stop() {
        requestObserver?.cancel()
        requestObserver = nil
        registeredKernel?.unregisterProvider((any AppUpdateChannelProviding).self)
        registeredKernel = nil
    }
}
