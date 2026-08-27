import KitAgentTool
import Foundation
import KernelCore
import ProviderMessage
import ProviderSettingView
import ProviderToolManager

@MainActor
public final class ComputerUseSuperPlugin: SuperPlugin {
    public let id = "com.coffic.lumi.plugin.computer-use"
    public let order = 278
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.computer-use",
        name: "Computer Use",
        description: "See and operate allowed macOS application windows through screenshots and structured UI actions.",
        category: .integration,
        stage: .preview,
        policy: .alwaysOn
    )

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ToolManagerProviding).self)?.add(
            ComputerObserveV2Tool(),
            pluginID: id
        )
        kernel.resolveProvider((any ToolManagerProviding).self)?.add(
            ComputerActV2Tool(),
            pluginID: id
        )
        kernel.resolveProvider((any SettingViewProviding).self)?.addEntries([
            SettingEntryItem(
                id: "\(id).settings",
                title: LumiPluginLocalization.string("Computer Use", bundle: .module),
                systemImage: "cursorarrow.motionlines",
                order: order
            ) {
                ComputerUseSettingsView()
            },
        ])
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.remove(id: ComputerObserveV2Tool.toolName)
        tools?.remove(id: ComputerActV2Tool.toolName)
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: ["\(id).settings"])
    }
}

public struct ComputerObserveV2Tool: SuperAgentTool {
    public static let toolName = "computer_observe"
    public let name = toolName
    private let service: ComputerUseService

    init(service: ComputerUseService = .shared) { self.service = service }

    public func description(for language: LanguagePreference) -> String {
        "Capture one allowed visible macOS application window as an image. Always observe before acting and use coordinates only from the latest observation."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [
            "application": ["type": "string", "description": "Optional application name or exact bundle identifier."],
            "window_title": ["type": "string", "description": "Optional case-insensitive window-title substring."],
        ], "additionalProperties": false]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        if let application = arguments["application"]?.value as? String, !application.isEmpty {
            return "观察 \(application)"
        }
        return "观察当前应用窗口"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await executeResult(arguments: arguments).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let result = try await service.observe(
            application: arguments["application"]?.value as? String,
            windowTitle: arguments["window_title"]?.value as? String
        )
        return ToolCallResult(
            content: ComputerUseV2Support.resultDescription(result),
            images: [ComputerUseV2Support.imageAttachment(from: result.attachment)]
        )
    }
}

public struct ComputerActV2Tool: SuperAgentTool {
    public static let toolName = "computer_act"
    public let name = toolName
    private let service: ComputerUseService

    init(service: ComputerUseService = .shared) { self.service = service }

    public func description(for language: LanguagePreference) -> String {
        "Execute up to 20 structured UI actions against a recent computer_observe result, then return a fresh screenshot. The target app must be allowed in Settings."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [
            "observation_id": ["type": "string"],
            "actions": ["type": "array", "minItems": 1, "maxItems": 20],
        ], "required": ["observation_id", "actions"], "additionalProperties": false]
    }

    public func displayDescription(for arguments: [String: ToolArgument]) -> String {
        let count = (arguments["actions"]?.value as? [Any])?.count ?? 0
        return "执行 \(count) 个界面操作"
    }

    public func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        guard let rawID = arguments["observation_id"]?.value as? String,
              let observationID = UUID(uuidString: rawID),
              service.isApplicationAllowed(for: observationID),
              let actions = try? ComputerUseV2Support.actions(from: arguments["actions"]?.value)
        else { return .high }
        return actions.contains(where: \.changesState) ? .high : .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await executeResult(arguments: arguments).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        guard let rawID = arguments["observation_id"]?.value as? String,
              let observationID = UUID(uuidString: rawID)
        else { throw ComputerUseError.invalidArguments("observation_id must be a UUID") }
        let actions = try ComputerUseV2Support.actions(from: arguments["actions"]?.value)
        let result = try await service.act(observationID: observationID, actions: actions)
        return ToolCallResult(
            content: ComputerUseV2Support.resultDescription(result),
            images: [ComputerUseV2Support.imageAttachment(from: result.attachment)]
        )
    }
}

private enum ComputerUseV2Support {
    static func actions(from value: Any?) throws -> [ComputerUseAction] {
        try ComputerUseActionParser.parse(value)
    }

    static func imageAttachment(from attachment: UserImageAttachment) -> ImageAttachment {
        ImageAttachment(
            id: attachment.id,
            data: Data(base64Encoded: attachment.base64Data) ?? Data(),
            mimeType: attachment.mimeType,
            fileName: attachment.fileName
        )
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
