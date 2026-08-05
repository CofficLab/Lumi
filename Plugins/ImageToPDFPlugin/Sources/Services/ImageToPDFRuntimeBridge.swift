import Foundation
import os

/// Runtime bridge that hands the LumiKernel-provided plugin data directory
/// down to the `ImageToPDFViewModel`.
///
/// - `ImageToPDFPlugin.onBoot` writes `directoryURL` (from
///   `kernel.storage?.pluginDataDirectory(for: "ImageToPDF")`) before the
///   view model ever needs it.
/// - `ImageToPDFViewModel.makeStagingDirectory()` reads it at conversion
///   time; if it's `nil`, the directory falls back to a unique temporary
///   folder so the plugin still works in degraded environments.
///
/// Using `OSAllocatedUnfairLock` satisfies Swift 6 strict concurrency checks
/// (avoids non-isolated mutable global state).
enum ImageToPDFRuntimeBridge {
    private static let lock = OSAllocatedUnfairLock<URL?>(initialState: nil)

    static var directoryURL: URL? {
        get { lock.withLock { $0 } }
        set { lock.withLock { $0 = newValue } }
    }
}