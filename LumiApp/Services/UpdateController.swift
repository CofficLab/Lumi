import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject, SPUUpdaterDelegate {
    static let shared = UpdateController()

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: nil
    )

    private var pendingImmediateInstallHandler: (() -> Void)?

    var updater: SPUUpdater {
        updaterController.updater
    }

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdatesRequest),
            name: .checkForUpdates,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInstallPreparedAppUpdateRequest),
            name: .installPreparedAppUpdate,
            object: nil
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    func updater(
        _ updater: SPUUpdater,
        willInstallUpdateOnQuit item: SUAppcastItem,
        immediateInstallationBlock immediateInstallHandler: @escaping () -> Void
    ) -> Bool {
        pendingImmediateInstallHandler = immediateInstallHandler
        NotificationCenter.postAppUpdateReadyToInstall(version: item.displayVersionString)
        return true
    }

    @objc private func handleCheckForUpdatesRequest() {
        checkForUpdates()
    }

    @objc private func handleInstallPreparedAppUpdateRequest() {
        guard let pendingImmediateInstallHandler else { return }
        pendingImmediateInstallHandler()
    }
}
