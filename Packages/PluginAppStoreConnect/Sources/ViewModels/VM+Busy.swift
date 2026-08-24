import Foundation

extension VM {
    func runBusy(forceRefresh: Bool = false, _ operation: () async throws -> Void) async {
        let startTime = ContinuousClock.now
        isBusy = false
        errorMessage = nil
        let previousPolicy = client.fetchPolicy
        if forceRefresh {
            client.fetchPolicy = .networkOnly
        }

        let overlayDelayTask = Task { @MainActor in
            do {
                try await Task.sleep(for: Self.loadingOverlayDelay)
                isBusy = true
            } catch {
                // Cancelled when the operation finishes before the delay elapses.
            }
        }

        defer {
            overlayDelayTask.cancel()
            client.fetchPolicy = previousPolicy
            isBusy = false
        }

        do {
            try await operation()
        } catch {
            Self.logger.error("\(self.t)operation failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
        Self.logger.info("\(self.t)runBusy completed in \((ContinuousClock.now - startTime).formatted())")
    }
}
