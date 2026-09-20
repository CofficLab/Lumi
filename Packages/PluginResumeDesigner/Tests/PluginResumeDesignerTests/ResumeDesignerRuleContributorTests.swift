import Testing
@testable import PluginResumeDesigner

struct ResumeDesignerRuleContributorTests {
    @Test("简历设计插件从 Markdown 资源贡献 Agent Rule")
    func loadsResumeRuleFromResource() {
        let contributor = ResumeDesignerRuleContributor()
        let rule = contributor.allRules.first

        #expect(contributor.providerID == "com.coffic.lumi.plugin.resume-designer")
        #expect(rule?.id == "resume-designer-workflow")
        #expect(rule?.title == "Resume Designer Workflow")
        #expect(rule?.content.contains("paper dimensions") == true)
        #expect(rule?.content.contains("output directory explicitly provided") == true)
    }
}
