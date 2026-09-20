import Testing
@testable import PluginAppIconDesigner

struct AppIconDesignerRuleContributorTests {
    @Test("图标设计插件贡献自己的 Agent Rule")
    func contributesAppIconRule() {
        let contributor = AppIconDesignerRuleContributor()
        let rule = contributor.allRules.first

        #expect(contributor.providerID == "com.coffic.lumi.plugin.app-icon-designer")
        #expect(rule?.id == "app-icon-designer-workflow")
        #expect(rule?.content.contains("source of truth") == true)
    }
}
