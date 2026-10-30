import Foundation
import KitAgentTool
import Testing
@testable import ComputerUsePlugin

/// 系统权限提示载荷的编解码。
///
/// 载荷随 tool result 的 `content` 传递，因此「能原样解回来」是渲染层
/// 能够接管该行的前提；解不回来就退化成纯文本错误，用户又只能自己找入口。
@Suite("Computer Use 系统权限载荷")
struct ComputerUseSystemPermissionPayloadTests {

    @Test("失败结果可原样解码回系统权限请求")
    func payloadRoundTrips() throws {
        let result = ComputerUseSystemPermissionCoordinator.failureResult(
            permission: .accessibility,
            operation: "computer_observe"
        )

        let request = try #require(
            ComputerUseSystemPermissionCoordinator.request(from: result.content)
        )
        #expect(request.permission == .accessibility)
        #expect(request.operation == "computer_observe")
    }

    @Test("屏幕录制权限同样可往返")
    func screenRecordingRoundTrips() throws {
        let result = ComputerUseSystemPermissionCoordinator.failureResult(
            permission: .screenRecording,
            operation: "computer_act"
        )

        let request = try #require(
            ComputerUseSystemPermissionCoordinator.request(from: result.content)
        )
        #expect(request.permission == .screenRecording)
        #expect(request.operation == "computer_act")
    }

    @Test("失败结果内容含可读原因，供 LLM 与结果气泡阅读")
    func failureContentCarriesReadableReason() {
        let result = ComputerUseSystemPermissionCoordinator.failureResult(
            permission: .accessibility,
            operation: "computer_observe"
        )

        // 载荷之前的部分是给模型看的可读文本：不能只是 JSON，
        // 否则模型只会看到一段无法理解的标记。
        let readable = result.content.components(separatedBy: ComputerUseSystemPermissionCoordinator.payloadSeparator).first ?? ""
        #expect(!readable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(result.isError)
    }

    @Test("非系统权限内容不会被误认为系统权限请求")
    func foreignContentIsNotASystemPermissionRequest() {
        #expect(ComputerUseSystemPermissionCoordinator.request(from: "plain text") == nil)
        #expect(ComputerUseSystemPermissionCoordinator.request(from: "") == nil)
        // 应用级授权载荷不是系统权限载荷，两者不能互相误判。
        #expect(
            ComputerUseSystemPermissionCoordinator.request(
                from: #"{"kind":"computer_use_authorization"}"#
            ) == nil
        )
    }
}

/// 系统权限缺失时的错误映射。
///
/// 关键契约：系统权限缺失**不能挂起回合**。用户无法在聊天里授予
/// macOS TCC 权限，挂起只会让回合永远等一个不会到来的回答。
@Suite("Computer Use 系统权限错误映射")
struct ComputerUseSystemPermissionMappingTests {

    private func makeCoordinator() -> (coordinator: ComputerUseAuthorizationCoordinator, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseSystemPerm-\(UUID().uuidString)", isDirectory: true)
        return (ComputerUseAuthorizationCoordinator(
            authorization: ComputerUseAuthorizationStore(dataDirectory: directory)
        ), directory)
    }

    @Test("辅助功能权限缺失返回带载荷的失败结果，且不挂起回合")
    func accessibilityBecomesPayloadFailure() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "accessibility_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.accessibilityPermissionRequired
        }

        #expect(result.isError)
        #expect(!result.awaitingUserResponse)
        let request = try #require(
            ComputerUseSystemPermissionCoordinator.request(from: result.content)
        )
        #expect(request.permission == .accessibility)
    }

    @Test("屏幕录制权限缺失返回带载荷的失败结果，且不挂起回合")
    func screenRecordingBecomesPayloadFailure() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.screenRecordingPermissionRequired
        }

        #expect(result.isError)
        #expect(!result.awaitingUserResponse)
        let request = try #require(
            ComputerUseSystemPermissionCoordinator.request(from: result.content)
        )
        #expect(request.permission == .screenRecording)
    }

    @Test("应用级授权仍然挂起回合，不被系统权限分支吞掉")
    func applicationAuthorizationStillSuspends() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.authorizationRequired(
                applicationName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                operation: "computer_observe"
            )
        }

        #expect(result.awaitingUserResponse)
        #expect(!result.isError)
        // 挂起载荷不是系统权限载荷，两者必须能区分。
        #expect(ComputerUseSystemPermissionCoordinator.request(from: result.content) == nil)
    }

    @Test("其它错误仍走普通失败，不携带系统权限载荷")
    func otherErrorsRemainPlainFailures() async throws {
        let (coordinator, directory) = makeCoordinator()
        defer { try? FileManager.default.removeItem(at: directory) }

        let result = await ComputerUseToolSuspension.execute(
            operation: "computer_observe",
            coordinator: coordinator
        ) {
            throw ComputerUseError.noMatchingWindow
        }

        #expect(result.isError)
        #expect(!result.awaitingUserResponse)
        #expect(ComputerUseSystemPermissionCoordinator.request(from: result.content) == nil)
    }
}

/// 渲染器接管边界。
@Suite("Computer Use 系统权限渲染器")
struct ComputerUseSystemPermissionRendererTests {

    private func makeFailureCall(
        id: String,
        permission: ComputerUseSystemPermission
    ) -> ToolCall {
        ToolCall(
            id: id,
            name: ComputerObserveV2Tool.toolName,
            arguments: "{}",
            result: ComputerUseSystemPermissionCoordinator.failureResult(
                permission: permission,
                operation: "computer_observe"
            )
        )
    }

    @Test("渲染器接管系统权限失败结果")
    func rendererClaimsSystemPermissionFailure() {
        let renderer = ComputerUseSystemPermissionRowRenderer()

        #expect(renderer.canRender(toolCall: makeFailureCall(id: "call-1", permission: .accessibility)))
        #expect(renderer.canRender(toolCall: makeFailureCall(id: "call-2", permission: .screenRecording)))
    }

    @Test("渲染器不接管普通失败结果")
    func rendererIgnoresOrdinaryFailure() {
        let renderer = ComputerUseSystemPermissionRowRenderer()

        let ordinary = ToolCall(
            id: "call-3",
            name: ComputerObserveV2Tool.toolName,
            arguments: "{}",
            result: ToolCallResult(content: "No matching window.", isError: true)
        )
        #expect(!renderer.canRender(toolCall: ordinary))

        // 没有结果的调用同样不该被接管。
        let withoutResult = ToolCall(
            id: "call-4",
            name: ComputerObserveV2Tool.toolName,
            arguments: "{}"
        )
        #expect(!renderer.canRender(toolCall: withoutResult))
    }

    @Test("渲染器不接管应用级授权挂起载荷")
    func rendererIgnoresAuthorizationSuspension() {
        let renderer = ComputerUseSystemPermissionRowRenderer()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseRenderer-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let coordinator = ComputerUseAuthorizationCoordinator(
            authorization: ComputerUseAuthorizationStore(dataDirectory: directory)
        )

        let suspended = ToolCall(
            id: "call-5",
            name: ComputerObserveV2Tool.toolName,
            arguments: "{}",
            result: coordinator.pendingResult(
                applicationName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                operation: "computer_observe"
            )
        )
        #expect(!renderer.canRender(toolCall: suspended))
    }

    @Test("渲染器优先级高于通用工具授权卡片")
    func rendererOutranksGenericApproval() {
        #expect(ComputerUseSystemPermissionRowRenderer.priority > 120)
    }
}

/// 权限枚举的展示契约。
@Suite("Computer Use 系统权限展示")
struct ComputerUseSystemPermissionDisplayTests {

    @Test("每种权限都有非空的展示名与说明文案")
    func everyPermissionHasDisplayText() {
        for permission in ComputerUseSystemPermission.allCases {
            #expect(!permission.displayName.isEmpty)
            #expect(!permission.openSystemSettingsTitle.isEmpty)
            #expect(!permission.missingPermissionMessage.isEmpty)
        }
    }

    @Test("权限说明文案点名具体权限，便于模型归因")
    func messageNamesThePermission() {
        // 文案措辞随本地化变化，只断言与语言无关的契约：必须区分两种权限。
        #expect(
            ComputerUseSystemPermission.accessibility.missingPermissionMessage
                != ComputerUseSystemPermission.screenRecording.missingPermissionMessage
        )
    }
}
