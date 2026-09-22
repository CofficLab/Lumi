import Testing
@testable import PluginAppStoreConnect

struct AppStoreConnectRuleContributorTests {
    @Test("App Store Connect 插件从 Markdown 资源贡献 Agent Rule")
    func loadsReleaseSafetyRuleFromResource() {
        let contributor = AppStoreConnectRuleContributor()
        let rule = contributor.allRules.first

        #expect(contributor.providerID == "com.coffic.lumi.plugin.app-store-connect")
        #expect(rule?.id == "app-store-connect-release-safety")
        #expect(rule?.title == "App Store Connect Release Safety")
        #expect(rule?.content.contains("never guess identifiers") == true)
        #expect(rule?.content.contains("mutate remote data") == true)
    }
}
