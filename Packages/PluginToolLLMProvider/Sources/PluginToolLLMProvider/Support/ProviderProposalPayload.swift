import Foundation

/// 提案载荷的编解码。
///
/// 工具结果文本末尾追加一段 ```json 代码块，渲染器再把它解回提案——
/// 这是 Lumi 里「工具给 LLM 读文本 + 给 UI 读结构化数据」的既有约定
/// （见 `NewConversationRowRenderer`）。
enum ProviderProposalPayload {

    /// JSON 代码块标记。
    static let codeBlockMarker = "```json"

    /// 把提案编码为 JSON 代码块。
    ///
    /// - Returns: 形如 ```` ```json\n{...}\n``` ```` 的文本；编码失败时返回空串。
    static func encode(_ proposal: LLMProviderProposal) -> String {
        guard let data = try? JSONEncoder().encode(proposal),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }
        return "\(codeBlockMarker)\n\(json)\n```"
    }

    /// 从工具结果文本中解出提案。
    ///
    /// 正文里可能存在**多段** JSON 代码块（LLM 给的说明文字里常带示例代码块），
    /// 因此这里从**最后一段**开始逐段尝试解码，命中第一段能解成提案的即返回。
    /// 载荷块由本插件追加在正文末尾，从后往前找正好命中它。
    static func decode(from content: String) -> LLMProviderProposal? {
        for json in extractJSONBlocks(from: content).reversed() {
            guard let data = json.data(using: .utf8),
                  let proposal = try? JSONDecoder().decode(LLMProviderProposal.self, from: data) else {
                continue
            }
            return proposal
        }
        return nil
    }

    /// 取出文本里全部 JSON 代码块的内容，按出现顺序排列。
    static func extractJSONBlocks(from content: String) -> [String] {
        var blocks: [String] = []
        var searchStart = content.startIndex
        while let markerRange = content.range(of: codeBlockMarker, range: searchStart..<content.endIndex) {
            let afterMarker = markerRange.upperBound
            guard let end = content.range(of: "```", range: afterMarker..<content.endIndex)?.lowerBound else {
                break
            }
            let json = content[afterMarker..<end].trimmingCharacters(in: .whitespacesAndNewlines)
            if !json.isEmpty {
                blocks.append(json)
            }
            searchStart = end
        }
        return blocks
    }

    /// 取出第一段 JSON 代码块的内容。
    static func extractJSON(from content: String) -> String? {
        extractJSONBlocks(from: content).first
    }
}
