import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderProject
import ProviderRootView
import ProviderToolbar
import Testing
@testable import PluginGitWorkspace

@MainActor
@Test("Git workspace plugin registers an ActivityBar entry")
func gitWorkspacePluginRegistersEntry() throws {
    let kernel = KernelCoreContainer()
    try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
    try kernel.registerProvider((any ContentViewProviding).self, DefaultContentViewProviding())
    try kernel.registerProvider((any ProjectProviding).self, DefaultProjectProvider())
    try kernel.registerProvider((any RootViewProviding).self, DefaultRootViewProvider())
    try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())

    try GitWorkspacePlugin().onBoot(kernel: kernel)

    let activity = kernel.resolveProvider((any ActivityBarProviding).self)
    #expect(activity?.items.map(\.id) == ["com.coffic.lumi.plugin.git-workspace.entry"])
}
