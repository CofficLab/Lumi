import KernelCore
import ProviderNetwork

/// Lumi distribution-level update bootstrap.
///
/// Sparkle is deliberately host-owned rather than registered in
/// `FactoryLumi`'s generic plugin catalog: App Store builds must not link an
/// in-app updater. The Lumi host invokes this once after its V2 kernel has
/// registered `NetworkProviding`, preserving the old plugin's boot behavior.
@MainActor
public enum AppUpdateBootstrap {
    public static func start(kernel: KernelCoreContainer) {
        let service = UpdateService.shared
        if let network = kernel.resolveProvider((any NetworkProviding).self) {
            service.configure(network: network)
        }
        service.setupFeedURLIfNeeded()
    }
}
