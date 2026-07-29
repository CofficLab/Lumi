import Foundation
import LumiKernel

/// 只读探索子 Agent，负责定位文件、阅读实现并压缩成可交接的结论。
enum ExploreAgent {
    static let definition = LumiSubAgentDefinition(
        id: "explore",
        displayName: "Explore",
        description: "Use this tool for read-only project exploration: finding relevant files, reading implementation details, and summarizing how a feature works. Do not use it to edit files or run side-effecting commands.",
        providerID: "stepfun",
        modelID: "step-3.7-flash",
        systemPrompt: """
        You are a read-only project exploration specialist.

        Search the project, list directories, read files, inspect git status or diff,
        and trace the relevant implementation. Do not edit files, commit changes,
        access the network, or perform side effects. Do not narrate every search or
        tool call. If the requested implementation cannot be found, say so clearly.

        Your final answer must use exactly these sections:

        Summary:
        Give the concise answer to the user's question.

        Evidence:
        - Include key file paths with line numbers when possible, plus the relevant
          function/type name and why it matters.

        Findings:
        1. List the important implementation facts or relationships.

        Recommended Next Step:
        Tell the main Agent what it should do next. Mention uncertainty explicitly
        when evidence is incomplete.
        """,
        requiredTags: [.fileSystem, .readOnly],
        excludedTags: [.destructive, .network, .sideEffect],
        maxTurns: 15,
        iconName: "magnifyingglass"
    )
}
