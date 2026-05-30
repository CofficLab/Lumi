import Testing
@testable import PluginVueEditor

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func cssModulesParserHandlesMultiLineRules() {
    let css = """
    .container, .wrapper {
        display: flex;
        color: red;
    }
    """

    let entries = CSSModulesTypeGenerator.parseClassNames(from: css)

    #expect(entries.map(\.name) == ["container", "wrapper"])
    #expect(entries.first?.properties == ["display: flex", "color: red"])
}

@Test func cssModulesParserHandlesSingleLineRules() {
    let css = ".button { color: blue; font-weight: 600; }"

    let entries = CSSModulesTypeGenerator.parseClassNames(from: css)

    #expect(entries.count == 1)
    #expect(entries.first?.name == "button")
    #expect(entries.first?.properties == ["color: blue", "font-weight: 600"])
}
