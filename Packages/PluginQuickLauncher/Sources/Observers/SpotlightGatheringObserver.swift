import AppKit
import Foundation

/// Waits for Spotlight's initial gathering notification, with a timeout fallback.
@MainActor
final class SpotlightGatheringObserver {
    let stream: AsyncStream<Void>
    private var token: NSObjectProtocol?
    private var continuation: AsyncStream<Void>.Continuation?

    init(query: NSMetadataQuery, timeout: TimeInterval) {
        var continuation: AsyncStream<Void>.Continuation?
        stream = AsyncStream { value in
            continuation = value
        }
        self.continuation = continuation
        token = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.finish()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.finish()
        }
    }

    func finish() {
        continuation?.finish()
        continuation = nil
        if let token {
            NotificationCenter.default.removeObserver(token)
            self.token = nil
        }
    }

}
