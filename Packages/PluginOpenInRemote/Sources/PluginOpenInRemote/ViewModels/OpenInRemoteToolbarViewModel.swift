import Foundation
import ProviderToast

/// 为标题栏按钮提供当前项目状态，并在项目切换后刷新可用性。
@MainActor
final class OpenInRemoteToolbarViewModel: ObservableObject {
    /// 强引用能力 Adapter，保证 ViewModel 存续期间能力始终可用。
    private let projectCapability: OpenInRemoteProjectCapability
    private let resolver: RemoteRepositoryResolver
    private let toastCapability: OpenInRemoteToastCapability
    private var projectObserver: (any OpenInRemoteProjectObserverHandle)?

    @Published private(set) var currentProjectPath: String?
    @Published private(set) var isOpening = false

    init(
        projectCapability: OpenInRemoteProjectCapability,
        resolver: RemoteRepositoryResolver,
        toastCapability: OpenInRemoteToastCapability
    ) {
        self.projectCapability = projectCapability
        self.resolver = resolver
        self.toastCapability = toastCapability
        self.currentProjectPath = projectCapability.currentProjectPath
        self.projectObserver = projectCapability.addProjectObserver { [weak self] event in
            guard case let .currentProjectChanged(path) = event else { return }
            self?.currentProjectPath = path
        }
    }

    func cancel() {
        projectObserver?.cancel()
        projectObserver = nil
    }

    /// 在默认浏览器中打开当前项目的远程仓库。
    func openRemoteRepository() {
        guard !isOpening, let path = currentProjectPath else { return }
        isOpening = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isOpening = false }

            guard let url = await resolver.webURL(forRepositoryAt: path) else {
                toastCapability.notify(
                    OpenInRemoteLocalization.string("Cannot open the remote repository"),
                    detail: OpenInRemoteLocalization.string("No remote repository URL was found for this project."),
                    style: .warning
                )
                return
            }

            guard RemoteRepositoryOpener.open(url) else {
                toastCapability.notify(
                    OpenInRemoteLocalization.string("Cannot open the remote repository"),
                    detail: OpenInRemoteLocalization.string("The default browser could not be opened."),
                    style: .error
                )
                return
            }
        }
    }
}
