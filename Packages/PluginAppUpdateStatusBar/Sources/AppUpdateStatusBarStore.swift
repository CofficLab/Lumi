import Combine
import Foundation

@MainActor
final class AppUpdateStatusBarStore: ObservableObject {
    static let shared = AppUpdateStatusBarStore()

    @Published private(set) var pendingVersion: String?

    private var cancellables = Set<AnyCancellable>()

    var hasPendingUpdate: Bool {
        pendingVersion != nil
    }

    func start() {
        guard cancellables.isEmpty else { return }

        NotificationCenter.default.publisher(for: .appUpdateReadyToInstall)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let version = notification.userInfo?["version"] as? String
                self.pendingVersion = version?.isEmpty == false ? version : nil
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .installPreparedAppUpdate)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.clearPendingUpdate()
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        clearPendingUpdate()
    }

    func installPreparedUpdate() {
        NotificationCenter.postInstallPreparedAppUpdate()
    }

    private func clearPendingUpdate() {
        pendingVersion = nil
    }
}
