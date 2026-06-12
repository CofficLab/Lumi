import Combine
import Sparkle
import SwiftUI

struct CheckForUpdatesCommand: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            CheckForUpdatesMenuItem()
        }
    }
}

private struct CheckForUpdatesMenuItem: View {
    @StateObject private var viewModel = CheckForUpdatesViewModel()

    var body: some View {
        Button("检查更新...") {
            UpdateController.shared.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}

@MainActor
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private var cancellable: AnyCancellable?

    init() {
        let updater = UpdateController.shared.updater
        cancellable = updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: \.canCheckForUpdates, on: self)
    }
}
