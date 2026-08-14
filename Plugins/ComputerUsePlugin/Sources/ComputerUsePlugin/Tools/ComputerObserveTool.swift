import Foundation
import KernelLumi

public struct ComputerObserveTool: LumiAgentTool {
    public static let info = LumiAgentToolInfo(
        id: "computer_observe",
        displayName: "观察电脑窗口",
        description: "Capture one visible macOS application window and return it as an image. Call this before acting and again whenever the window changes. Coordinates in later actions use the returned image pixel dimensions."
    )

    public let tags: Set<LumiToolTag> = [.readOnly, .fast]
    private let service: ComputerUseService

    init(service: ComputerUseService = .shared) {
        self.service = service
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "application": .object([
                    "type": .string("string"),
                    "description": .string("Optional application name or exact bundle identifier. Omit to use the frontmost application.")
                ]),
                "window_title": .object([
                    "type": .string("string"),
                    "description": .string("Optional case-insensitive substring of the window title.")
                ]),
            ]),
            "additionalProperties": .bool(false),
        ])
    }

    public func riskLevel(arguments: [String: LumiJSONValue], kernel: KernelLumi) -> LumiCommandRiskLevel {
        .safe
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        if let application = arguments.string("application"), !application.isEmpty {
            return "观察 \(application)"
        }
        return "观察当前应用窗口"
    }

    public func execute(arguments: [String: LumiJSONValue], kernel: KernelLumi) async throws -> String {
        try kernel.checkCancellation()
        guard await Self.selectedModelSupportsComputerUse(
            kernel: kernel,
            conversationID: kernel.conversationID
        ) else {
            throw ComputerUseError.visionModelRequired
        }
        let result = try await service.observe(
            application: arguments.string("application"),
            windowTitle: arguments.string("window_title")
        )
        kernel.attachImage(result.attachment)
        return Self.resultDescription(result)
    }

    @MainActor
    static func selectedModelSupportsComputerUse(
        kernel: KernelLumi,
        conversationID: UUID
    ) -> Bool {
        guard let providerManager = kernel.llmProvider else { return false }
        let provider: (any LumiLLMProvider)?
        if let selectedProviderID = providerManager.selectedProviderID {
            provider = providerManager.llmProvider(id: selectedProviderID)
        } else {
            provider = providerManager.allLLMProviders().first
        }
        guard let provider else { return false }
        let info = provider.providerInfo
        let model = providerManager.selectedModel
            ?? kernel.conversations?.modelName(for: conversationID)
            ?? info.defaultModel
        guard let capabilities = info.modelInfo(for: model)?.capabilities else { return false }
        return capabilities.supportsVision && capabilities.supportsTools
    }

    static func resultDescription(_ result: ComputerUseService.ObservationResult) -> String {
        let observation = result.observation
        let allowed = result.isApplicationAllowed ? "allowed" : "not_allowed"
        return """
        Observation captured.
        observation_id: \(observation.id.uuidString)
        application: \(observation.window.applicationName)
        bundle_identifier: \(observation.window.bundleIdentifier)
        window_title: \(observation.window.windowTitle.isEmpty ? "(untitled)" : observation.window.windowTitle)
        image_coordinate_space: \(observation.imageWidth)x\(observation.imageHeight), origin is top-left
        application_control: \(allowed)
        Use only coordinates inside this image. Do not guess coordinates from an older observation.
        """
    }
}
