import Foundation

@MainActor
public protocol RecordingSessionObserverHandle: AnyObject {
    func cancel()
}

@MainActor
final class RecordingSessionObserver {
    private var handle: (any RecordingSessionObserverHandle)?

    init(manager: RecordingSessionManager, onChange: @escaping (RecordingActivity) -> Void) {
        handle = manager.addObserver(onChange)
    }

    func cancel() {
        handle?.cancel()
        handle = nil
    }
}

@MainActor
final class RecordingSessionObserverHandleImpl: RecordingSessionObserverHandle {
    private var cancellation: (() -> Void)?

    init(cancellation: @escaping () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let cancellation = self.cancellation
        self.cancellation = nil
        cancellation?()
    }
}
