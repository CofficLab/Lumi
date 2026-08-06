import Combine
import Foundation

/// Shared progress state for exporting a batch of HTTP logs.
///
/// The settings view drives it while a background task formats records, and
/// the status bar renders it live via `HTTPExportStatusBarView`.
@MainActor
public final class HTTPExportProgress: ObservableObject {
    public static let shared = HTTPExportProgress()

    @Published public private(set) var isExporting = false
    @Published public private(set) var completed = 0
    @Published public private(set) var total = 0
    @Published public private(set) var errorMessage: String?

    private init() {}

    /// Localized, compact text for the status bar, e.g. "Exporting 3/42".
    public var statusText: String {
        LumiPluginLocalization.string("Exporting", bundle: .module) + " \(completed)/\(total)"
    }

    public func begin(total: Int) {
        self.total = total
        completed = 0
        isExporting = true
        errorMessage = nil
    }

    public func advance() {
        guard isExporting else { return }
        completed = min(completed + 1, total)
    }

    public func fail(message: String) {
        errorMessage = message
        isExporting = false
    }

    public func finish() {
        isExporting = false
        completed = total
    }

    public func clearError() {
        errorMessage = nil
    }
}
