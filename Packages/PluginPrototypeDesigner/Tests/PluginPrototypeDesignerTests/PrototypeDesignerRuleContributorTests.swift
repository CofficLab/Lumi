import Testing
@testable import PluginPrototypeDesigner

struct PrototypeDesignerRuleContributorTests {
    @Test("原型设计插件从 Markdown 资源贡献 Agent Rule")
    func loadsPrototypeRuleFromResource() {
        let contributor = PrototypeDesignerRuleContributor()
        let rule = contributor.allRules.first

        #expect(contributor.providerID == "com.coffic.lumi.plugin.prototype-designer")
        #expect(rule?.id == "prototype-designer-workflow")
        #expect(rule?.title == "Prototype Designer Workflow")
        #expect(rule?.content.contains("prototype_preview_screen") == false)
        #expect(rule?.content.contains("data-prototype-link") == true)
        #expect(rule?.content.contains("project lint") == true)
    }
}
