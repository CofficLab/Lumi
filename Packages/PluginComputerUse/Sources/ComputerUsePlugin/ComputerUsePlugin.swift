import KitAgentTool
import Foundation
import KernelCore
import ProviderAgentLoop
import ProviderMessage
import ProviderMessageRendering
import ProviderSettingView
import ProviderRootView
import ProviderStorage
import ProviderToolManager
import LumiLoggingKit
import os

@MainActor
public final class ComputerUsePlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.computer-use", category: "ComputerUse")
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

    /// 历史实现把授权白名单存在 `UserDefaults.standard`，未使用插件专属目录。
    /// 目录名未变过，无需版本根搬迁。
    public let legacyDataDirectoryNames: [String] = []

    /// Computer Use 在设置侧边栏中的入口 ID。
    ///
    /// 设置入口与「打开 Lumi 设置」深链共用同一个 ID：后者通过
    /// `SettingViewNavigation` 通知把 ID 传回宿主，宿主据此选中该入口。
    public static let settingsEntryID = "com.coffic.lumi.plugin.computer-use.settings"

    private var settingsState: ComputerUseSettingsState?
    private var activationObserver: ApplicationActivationObserver?

    public init() {}

    /// 把 `UserDefaults.standard` 中的旧授权白名单并入插件专属存储。
    ///
    /// 只在目标 plist 尚无记录时导入，避免覆盖用户在插件内的后续修改。
    /// `UserDefaults` 内的原 key 保留，便于回退。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let legacyKey = "ComputerUse.nativeAllowedBundleIdentifiers"
        let legacyAllowedKey = "ComputerUse.alwaysAllowedBundleIdentifiers"
        guard let defaults = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") else {
            return
        }
        let nativeValues = (defaults[legacyKey] as? [String]) ?? []
        let allowedValues = (defaults[legacyAllowedKey] as? [String]) ?? []
        guard !nativeValues.isEmpty || !allowedValues.isEmpty else { return }

        let store = ComputerUseAuthorizationStore(dataDirectory: context.currentPluginDataDirectory)
        if !nativeValues.isEmpty, store.allowedBundleIdentifiers().isEmpty, store.isNativeAllowed(nativeValues[0]) == false {
            for bundleIdentifier in nativeValues {
                store.setNativeAllowed(true, bundleIdentifier: bundleIdentifier)
            }
            Self.logger.info("\(Self.t)Imported \(nativeValues.count) native authorization entries from UserDefaults")
        }
        for bundleIdentifier in allowedValues {
            store.setAllowed(true, bundleIdentifier: bundleIdentifier)
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        // 存储目录注入必须早于 ComputerUseAuthorizationStore.shared 的首次访问。
        if let storage = kernel.resolveProvider((any StorageProviding).self) {
            ComputerUseRuntime.configure(settingsDirectory: storage.pluginDataDirectory(for: id))
        }
        let settingsState = ComputerUseSettingsState()
        self.settingsState = settingsState
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.add(AccessibilityObserveTool(), pluginID: id)
        tools?.add(AccessibilityActTool(), pluginID: id)
        kernel.resolveProvider((any RootViewProviding).self)?.addOverlays([
            RootOverlayItem(id: "\(id).native-control", order: 900) {
                NativeControlRootOverlay(content: $0, state: .shared)
            },
        ])
        activationObserver = ApplicationActivationObserver { [weak settingsState] in
            settingsState?.refresh()
        }
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
                id: Self.settingsEntryID,
                title: pluginLocalization.string("Computer Use"),
                systemImage: "cursorarrow.motionlines",
                order: order
            ) {
                ComputerUseSettingsView(state: settingsState)
            },
        ])
        // 聊天内授权卡片：工具挂起等待授权时，直接在消息列表里让用户决定。
        ComputerUseAuthorizationBridge.shared.start(kernel: kernel)
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?.register(
            ComputerUseAuthorizationRowRenderer()
        )
        // 系统权限提示卡：工具因缺少辅助功能/屏幕录制权限失败时，
        // 在消息列表里给出直达系统设置与 Lumi 设置的按钮。
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?.register(
            ComputerUseSystemPermissionRowRenderer()
        )
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.remove(id: ComputerObserveV2Tool.toolName)
        tools?.remove(id: ComputerActV2Tool.toolName)
        tools?.remove(id: "accessibility_observe")
        tools?.remove(id: "accessibility_act")
        NativeControlCoordinator.shared.shutdown()
        kernel.resolveProvider((any RootViewProviding).self)?.removeOverlays(ids: ["\(id).native-control"])
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?.unregister(
            id: ComputerUseAuthorizationRowRenderer.id
        )
        kernel.resolveProvider((any ToolCallRenderingProviding).self)?.unregister(
            id: ComputerUseSystemPermissionRowRenderer.id
        )
        ComputerUseAuthorizationBridge.shared.stop()
        activationObserver?.cancel()
        activationObserver = nil
        settingsState = nil
        kernel.resolveProvider((any SettingViewProviding).self)?.removeEntries(ids: [Self.settingsEntryID])
    }
}

public struct ComputerObserveV2Tool: SuperAgentTool, ComputerUseSuspendingTool {
    public static let toolName = "computer_observe"
    public let name = toolName
    private let service: ComputerUseService

    init(service: ComputerUseService = .shared) { self.service = service }

    public func description(for language: LanguagePreference) -> String {
        "Capture one allowed visible macOS application window as an image without activating it. Prefer accessibility_observe for controls; screenshots are useful for visual verification and native fallback. Always use fresh coordinates."
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
        await executeWithAuthorizationSuspension(operation: "computer_observe") { [self] in
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
}

public struct ComputerActV2Tool: SuperAgentTool, ComputerUseSuspendingTool {
    public static let toolName = "computer_act"
    public let name = toolName
    private let service: ComputerUseService

    init(service: ComputerUseService = .shared) { self.service = service }

    public func description(for language: LanguagePreference) -> String {
        "Fallback only: after accessibility_observe cannot accomplish the operation, execute up to 10 UI actions (max 20 seconds) using a fresh computer_observe result. Requires reason explaining why native input is necessary. Lumi shows a desktop-control notice and pauses on user input; never bypass with shell scripts. Re-observe after interruptions; actions may have partially completed."
    }

    public func inputSchema(for language: LanguagePreference) -> [String: Any] {
        ["type": "object", "properties": [
            "observation_id": ["type": "string"],
            "actions": ["type": "array", "minItems": 1, "maxItems": 10],
            "reason": ["type": "string", "description": "Short user-facing explanation of the operation and why AX cannot perform it."],
        ], "required": ["observation_id", "actions", "reason"], "additionalProperties": false]
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
        await executeWithAuthorizationSuspension(operation: "computer_act") { [self] in
            guard let rawID = arguments["observation_id"]?.value as? String,
                  let observationID = UUID(uuidString: rawID)
            else { throw ComputerUseError.invalidArguments("observation_id must be a UUID") }
            let actions = try ComputerUseV2Support.actions(from: arguments["actions"]?.value)
            let result = try await service.act(observationID: observationID, actions: actions, reason: arguments["reason"]?.value as? String ?? "")
            return ToolCallResult(
                content: ComputerUseV2Support.resultDescription(result),
                images: [ComputerUseV2Support.imageAttachment(from: result.attachment)]
            )
        }
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
