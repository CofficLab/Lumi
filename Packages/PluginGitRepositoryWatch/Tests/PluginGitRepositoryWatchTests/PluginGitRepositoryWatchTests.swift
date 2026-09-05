import Foundation
import KernelCore
import ProviderGitRepositoryWatch
import ProviderProject
import Testing
@testable import PluginGitRepositoryWatch

@MainActor
@Suite("PluginGitRepositoryWatch")
struct PluginGitRepositoryWatchTests {
    @Test("non-git directory does not leave an active watcher")
    func nonGitDirectoryIsIgnored() {
        let provider = GitRepositoryWatchProvider()
        provider.startWatching(repositoryURL: URL(fileURLWithPath: "/tmp/not-a-git-repository"))

        #expect(provider.watchingRepositoryURL == nil)
        #expect(provider.isWatcherActive == false)
        #expect(provider.watchedGitDirectoryPath == nil)
    }

    @Test("watch plugin registers the reusable provider")
    func pluginRegistersProvider() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any ProjectProviding).self, DefaultProjectProvider())
        try GitRepositoryWatchPlugin().onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any GitRepositoryWatching).self) != nil)
    }
}
