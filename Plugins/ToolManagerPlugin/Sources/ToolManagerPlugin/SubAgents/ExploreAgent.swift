import Foundation
import KernelLumi

/// 只读探索子 Agent（继承当前选中供应商/模型）。
///
/// 负责定位文件、阅读实现、追踪架构，并把结论压缩成交接摘要。
/// 不修改文件、不执行有副作用的命令。
enum ExploreAgent {
    static let definition = LumiSubAgentDefinition(
        id: "builtin-explore",
        displayName: "Explore",
        description: """
        Use this tool for read-only project exploration: finding relevant files, reading \
        implementation details, tracing how a feature works, or inspecting git state. \
        It runs on the host's currently selected model and returns a compressed hand-off \
        summary. Do not use it to edit files or run side-effecting commands.
        """,
        // 继承模式下 providerID/modelID 会被忽略，留空占位。
        providerID: "",
        modelID: "",
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
        iconName: "magnifyingglass",
        inheritsSelectedProvider: true
    )
}
