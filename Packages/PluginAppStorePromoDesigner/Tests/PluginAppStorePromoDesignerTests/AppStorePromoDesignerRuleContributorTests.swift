import Testing
@testable import PluginAppStorePromoDesigner

struct AppStorePromoDesignerRuleContributorTests {
    @Test("促销图设计插件从 Markdown 资源贡献 Agent Rule")
    func loadsPromoRuleFromResource() {
        let contributor = AppStorePromoDesignerRuleContributor()
        let rule = contributor.allRules.first

        #expect(contributor.providerID == "com.coffic.lumi.plugin.app-store-promo-designer")
        #expect(rule?.id == "app-store-promo-designer-workflow")
        #expect(rule?.title == "App Store Promo Designer Workflow")
        #expect(rule?.content.contains("Preview the rendered image") == true)
        #expect(rule?.content.contains("task lint") == true)
    }
}
