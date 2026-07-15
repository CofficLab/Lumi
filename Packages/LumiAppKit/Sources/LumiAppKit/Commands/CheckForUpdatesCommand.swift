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
            UpdateService.shared.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}

@MainActor
private final class CheckForUpdatesViewModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    private var cancellable: AnyCancellable?

    init() {
        // 确保 updater 已初始化，再订阅 canCheckForUpdates。
        // 之前此处仅做可选绑定，若 updater 尚未就绪（setupFeedURLIfNeeded 的
        // detached Task 还没回来），KVO 订阅永远不会创建，菜单项会一直灰色。
        UpdateService.shared.ensureUpdaterInitialized()
        if let updater = UpdateService.shared.updater {
            cancellable = updater.publisher(for: \.canCheckForUpdates)
                .receive(on: RunLoop.main)
                .assign(to: \.canCheckForUpdates, on: self)
        }
    }
}
