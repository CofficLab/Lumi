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

    /// 把 `UserDefaults.standard` 中的旧授权数据并入插件专属存储。
    ///
    /// 只导入**原生控制授权**（`ComputerUse.nativeAllowedBundleIdentifiers`）：
    /// 它记录的是「Lumi 接管过这个 App 的鼠标键盘」，与运行时横幅的确认直接相关，
    /// 升级后应当延续。
    ///
    /// 旧版的**显式应用白名单**（`ComputerUse.alwaysAllowedBundleIdentifiers`）
    /// 不再导入，并从存储中清除：应用访问权现在由会话的自动化等级决定，
    /// 留着这份名单只会让用户以为自己还能管理一份实际无效的名单。
    public func migrateData(context: PluginDataMigrationContext) throws {
        let legacyKey = "ComputerUse.nativeAllowedBundleIdentifiers"
        guard let defaults = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") else {
            return
        }
        let nativeValues = (defaults[legacyKey] as? [String]) ?? []

        let store = ComputerUseAuthorizationStore(dataDirectory: context.currentPluginDataDirectory)
        // 清除旧版显式白名单：它不再参与任何判定。
        store.purgeLegacyExplicitAllowlist()
        guard !nativeValues.isEmpty else { return }
        if store.isNativeAllowed(nativeValues[0]) == false {
            for bundleIdentifier in nativeValues {
                store.setNativeAllowed(true, bundleIdentifier: bundleIdentifier)
            }
            Self.logger.info("\(Self.t)Imported \(nativeValues.count) native authorization entries from UserDefaults")
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

    /// 会话自动化等级的取数入口在 `onReady` 注入。
    ///
    /// `onReady` 在全部插件 `onBoot` 之后执行，此时 `ConversationManaging`
    /// 一定可以解析；`onBoot` 阶段解析会拿到空引用。
    public func onReady(kernel: KernelCoreContainer) throws {
        ComputerUseAutomationLevelProvider.shared.start(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        ComputerUseAutomationLevelProvider.shared.stop()
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.remove(id: ComputerObserveV2Tool.toolName)
        tools?.remove(id: ComputerActV2Tool.toolName)
        tools?.remove(id: "accessibility_observe")
        tools?.remove(id: "accessibility_act")
        NativeControlCoordinator.shared.shutdown()
        // 遮罩是桌面级浮层，插件卸载后必须立即移除，不能残留在用户桌面上。
        ComputerUseTargetOverlayController.shared.removeImmediately()
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
        await performExecute(context: nil, arguments: arguments)
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        await performExecute(context: context, arguments: arguments)
    }

    /// 授权卡片回答「允许」后必须重新执行，才能生成截图和新的 observation_id。
    public func userResponseAction(
        for answer: String,
        arguments: [String: ToolArgument]
    ) -> ToolUserResponseAction {
        _ = arguments
        return computerUseUserResponseAction(for: answer)
    }

    /// 执行观察。`context` 为 `nil` 时按 A2 保守处理（仍会弹一次性授权卡片）。
    private func performExecute(
        context: ToolExecutionContext?,
        arguments: [String: ToolArgument]
    ) async -> ToolCallResult {
        let access = await ComputerUseAccessContextResolver.resolve(context)
        return await executeWithAuthorizationSuspension(operation: "computer_observe") { [self] in
            let result = try await service.observe(
                application: arguments["application"]?.value as? String,
                windowTitle: arguments["window_title"]?.value as? String,
                context: access
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
        // 目标应用是否获授权取决于会话上下文（等级 + 会话授权），
        // 而风险评估接口拿不到上下文。因此这里只按「动作是否会改变状态」判断：
        // 改变状态的原生输入一律高风险；观察与截图是低风险。
        guard let actions = try? ComputerUseV2Support.actions(from: arguments["actions"]?.value)
        else { return .high }
        return actions.contains(where: \.changesState) ? .high : .low
    }

    public func execute(arguments: [String: ToolArgument]) async throws -> String {
        try await executeResult(arguments: arguments).content
    }

    public func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        await performExecute(context: nil, arguments: arguments)
    }

    public func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        await performExecute(context: context, arguments: arguments)
    }

    /// 授权卡片回答「允许」后必须重新执行，才能真实执行界面操作。
    public func userResponseAction(
        for answer: String,
        arguments: [String: ToolArgument]
    ) -> ToolUserResponseAction {
        _ = arguments
        return computerUseUserResponseAction(for: answer)
    }

    /// 执行原生输入操作。`context` 为 `nil` 时按 A2 保守处理。
    private func performExecute(
        context: ToolExecutionContext?,
        arguments: [String: ToolArgument]
    ) async -> ToolCallResult {
        let access = await ComputerUseAccessContextResolver.resolve(context)
        return await executeWithAuthorizationSuspension(operation: "computer_act") { [self] in
            guard let rawID = arguments["observation_id"]?.value as? String,
                  let observationID = UUID(uuidString: rawID)
            else { throw ComputerUseError.invalidArguments("observation_id must be a UUID") }
            let actions = try ComputerUseV2Support.actions(from: arguments["actions"]?.value)
            let result = try await service.act(
                observationID: observationID,
                actions: actions,
                reason: arguments["reason"]?.value as? String ?? "",
                context: access
            )
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
        let authorized = result.isApplicationAuthorized ? "authorized" : "not_authorized"
        return """
        Observation captured.
        observation_id: \(observation.id.uuidString)
        application: \(observation.window.applicationName)
        bundle_identifier: \(observation.window.bundleIdentifier)
        window_title: \(observation.window.windowTitle.isEmpty ? "(untitled)" : observation.window.windowTitle)
        image_coordinate_space: \(observation.imageWidth)x\(observation.imageHeight), origin is top-left
        application_control: \(authorized)
        Use only coordinates inside this image. Do not guess coordinates from an older observation.
        """
    }
}
