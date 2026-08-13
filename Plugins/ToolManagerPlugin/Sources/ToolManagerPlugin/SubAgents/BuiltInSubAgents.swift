import KernelLumi

enum BuiltInSubAgents {
    static let definitions: [LumiSubAgentDefinition] = [
        BugFixerAgent.definition,
        CodeReviewAgent.definition,
        ExploreAgent.definition,
        ImageReaderAgent.definition,
        TestWriterAgent.definition,
    ]
}
