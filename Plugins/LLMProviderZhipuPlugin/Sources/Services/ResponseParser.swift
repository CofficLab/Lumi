import AgentToolKit
import Foundation

/// 智谱非流式响应解析
enum ResponseParser {
    static func parse(data: Data) throws -> (content: String, toolCalls: [ToolCall]?) {
        let result = try JSONDecoder().decode(ZhipuResponse.self, from: data)

        var textContent = ""
        var toolCalls: [ToolCall] = []

        for item in result.content {
            if item.type == "text", let text = item.text {
                textContent += text
            } else if item.type == "tool_use",
                      let id = item.id,
                      let name = item.name,
                      let inputDict = item.input {
                let normalDict = inputDict.mapValues { $0.value }
                let inputData = try JSONSerialization.data(withJSONObject: normalDict)
                let inputString = String(data: inputData, encoding: .utf8) ?? "{}"
                toolCalls.append(ToolCall(id: id, name: name, arguments: inputString))
            }
        }

        return (textContent, toolCalls.isEmpty ? nil : toolCalls)
    }
}

private struct ZhipuResponse: Decodable {
    let content: [ContentBlock]

    struct ContentBlock: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: ZhipuAnySendable]?
    }
}

private struct ZhipuAnySendable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictValue = try? container.decode([String: ZhipuAnySendable].self) {
            value = dictValue.mapValues { $0.value }
        } else if let arrayValue = try? container.decode([ZhipuAnySendable].self) {
            value = arrayValue.map { $0.value }
        } else {
            value = ""
        }
    }
}
