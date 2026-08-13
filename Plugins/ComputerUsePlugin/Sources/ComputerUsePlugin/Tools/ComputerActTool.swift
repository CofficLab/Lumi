import Foundation
import KernelLumi

public struct ComputerActTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "computer_act",
        displayName: "操作电脑窗口",
        description: "Execute a bounded batch of mouse or keyboard actions against a recent computer_observe result, then return a fresh screenshot. The target application must be allowed in Lumi Settings > Computer Use."
    )

    public let tags: Set<LumiToolTag> = [.sideEffect]
    private let service: ComputerUseService

    init(service: ComputerUseService = .shared) {
        self.service = service
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "observation_id": .object([
                    "type": .string("string"),
                    "description": .string("UUID returned by the most recent computer_observe or computer_act result.")
                ]),
                "actions": .object([
                    "type": .string("array"),
                    "minItems": .int(1),
                    "maxItems": .int(20),
                    "description": .string("Actions run in order. Supported types: screenshot, click, double_click, move, drag, scroll, type, keypress, wait."),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object([
                            "type": .object(["type": .string("string")]),
                            "x": .object(["type": .string("number")]),
                            "y": .object(["type": .string("number")]),
                            "button": .object(["type": .string("string"), "enum": .array([.string("left"), .string("right"), .string("center")])]),
                            "path": .object(["type": .string("array")]),
                            "delta_x": .object(["type": .string("number")]),
                            "delta_y": .object(["type": .string("number")]),
                            "text": .object(["type": .string("string")]),
                            "keys": .object(["type": .string("array"), "items": .object(["type": .string("string")])]),
                            "milliseconds": .object(["type": .string("integer"), "minimum": .int(0), "maximum": .int(10_000)]),
                        ]),
                        "required": .array([.string("type")]),
                    ]),
                ]),
            ]),
            "required": .array([.string("observation_id"), .string("actions")]),
            "additionalProperties": .bool(false),
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        guard let id = arguments.string("observation_id"),
              let observationID = UUID(uuidString: id),
              service.isApplicationAllowed(for: observationID),
              let actions = try? ComputerUseActionParser.parse(arguments["actions"])
        else { return .high }
        return actions.contains(where: \.changesState) ? .high : .low
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        let count: Int
        if case .array(let actions) = arguments["actions"] {
            count = actions.count
        } else {
            count = 0
        }
        return "执行 \(count) 个界面操作"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()
        guard let rawID = arguments.string("observation_id"),
              let observationID = UUID(uuidString: rawID)
        else {
            throw ComputerUseError.invalidArguments("observation_id must be a UUID")
        }
        let actions = try ComputerUseActionParser.parse(arguments["actions"])
        let result = try await service.act(observationID: observationID, actions: actions)
        kernel.attachImage(result.attachment)
        return ComputerObserveTool.resultDescription(result)
    }
}
