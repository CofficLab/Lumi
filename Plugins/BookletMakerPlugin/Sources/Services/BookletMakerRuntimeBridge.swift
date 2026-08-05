import Foundation

// MARK: - Booklet Maker Runtime Bridge

/// Holds plugin-wide runtime state that is shared between the boot
/// sequence (which has access to the kernel) and the view model (which
/// does not). Mirrors ``ImageToPDFRuntimeBridge``.
enum BookletMakerRuntimeBridge {

    /// Plugin data directory injected by ``BookletMakerPlugin/onBoot``.
    nonisolated(unsafe) static var directoryURL: URL?
}
