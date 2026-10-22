import Foundation
import Testing
@testable import AppUpdatePlugin

@Suite("Update request observer", .serialized)
@MainActor
struct UpdateRequestObserverTests {
    @Test("forwards both update commands and stops after cancellation")
    func forwardsAndCancelsNotifications() async throws {
        let calls = UpdateRequestCallCounts()
        let observer = UpdateRequestObserver(
            onCheckForUpdates: { calls.checks += 1 },
            onInstallPreparedUpdate: { calls.installs += 1 }
        )

        // 与包内其它投递同名通知的用例串行，避免计数互相污染。
        await AppUpdateNotificationGate.acquire()

        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(calls.checks == 1)
        #expect(calls.installs == 1)

        observer.cancel()
        observer.cancel()
        NotificationCenter.default.post(name: .checkForUpdates, object: nil)
        NotificationCenter.default.post(name: .installPreparedAppUpdate, object: nil)
        try? await Task.sleep(for: .milliseconds(100))

        #expect(calls.checks == 1)
        #expect(calls.installs == 1)

        await AppUpdateNotificationGate.release()
    }
}

@MainActor
private final class UpdateRequestCallCounts {
    var checks = 0
    var installs = 0
}
