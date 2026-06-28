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
        Button(String(localized: "Check for Updates...")) {
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
        // 使用可选绑定：如果 updater 尚未初始化（冷启动场景），
        // canCheckForUpdates 默认为 false，按钮禁用，直到 setupFeedURLIfNeeded 完成
        if let updater = UpdateController.shared.updater {
            cancellable = updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .assign(to: \.canCheckForUpdates, on: self)
        }
    }
}
