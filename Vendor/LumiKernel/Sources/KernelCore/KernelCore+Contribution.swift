import Foundation

// MARK: - Plugin contribution ownership

public extension KernelCoreContainer {
    /// 将一项共享贡献归属到当前生命周期回调中的插件，或显式指定插件。
    @discardableResult
    func trackContribution(
        ownerPluginID: String? = nil,
        cleanup: @escaping () -> Void
    ) throws -> PluginContributionToken {
        guard let owner = ownerPluginID ?? activePluginID,
              plugins[owner] != nil || activePluginID == owner else {
            throw KernelCoreError.contributionOwnerUnavailable
        }
        let token = PluginContributionToken(ownerPluginID: owner, cleanup: cleanup)
        contributionTokens[owner, default: []].append(token)
        return token
    }

    /// 撤回指定插件的全部共享贡献。逆注册顺序执行，便于恢复嵌套 UI/资源。
    func cancelContributions(ownedBy pluginID: String) {
        let tokens = contributionTokens.removeValue(forKey: pluginID) ?? []
        for token in tokens.reversed() {
            token.cancel()
        }
    }

    func activeContributionCount(ownedBy pluginID: String) -> Int {
        contributionTokens[pluginID, default: []].filter(\.isActive).count
    }
}
