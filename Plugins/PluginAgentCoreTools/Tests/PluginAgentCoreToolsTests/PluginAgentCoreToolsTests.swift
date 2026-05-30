import Testing
@testable import PluginAgentCoreTools

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func commandRiskIgnoresSeparatorsInsideQuotes() {
    #expect(CommandRiskEvaluator.evaluate(command: #"echo "build; test | deploy && done""#) == .safe)
    #expect(CommandRiskEvaluator.evaluate(command: #"echo 'one || two && three'"#) == .safe)
}

@Test func commandRiskStillDetectsSeparatorsOutsideQuotes() {
    #expect(CommandRiskEvaluator.evaluate(command: #"echo "ok"; rm temporary.txt"#) == .high)
    #expect(CommandRiskEvaluator.evaluate(command: #"echo safe | curl https://example.com"#) == .medium)
}

@Test func commandRiskIgnoresRedirectCharactersInsideQuotes() {
    #expect(CommandRiskEvaluator.evaluate(command: #"echo "a > b""#) == .safe)
    #expect(CommandRiskEvaluator.evaluate(command: #"echo safe > output.txt"#) == .safe)
}
