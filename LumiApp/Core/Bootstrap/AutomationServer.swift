import Foundation
import Network
import PluginEditorPreview
import SwiftUI
import os

// MARK: - Notification Extension

extension Notification.Name {
    /// 自动化服务器启动完成的通知
    /// userInfo: ["port": Int]
    static let automationServerDidStart = Notification.Name("automationServerDidStart")

    /// 自动化服务器停止的通知
    static let automationServerDidStop = Notification.Name("automationServerDidStop")

    /// 接收到自动化动作请求的通知
    /// userInfo: ["action": String, "payload": [String: Any]?]
    static let automationActionReceived = Notification.Name("automationActionReceived")

    /// 请求切换底部面板 Tab 的通知（自动化测试专用）
    /// userInfo: ["tabId": String]
    static let automationActivateBottomTab = Notification.Name("automationActivateBottomTab")
}

// MARK: - NotificationCenter Extension

extension NotificationCenter {
    /// 发送自动化服务器启动完成的通知
    /// - Parameter port: 监听的端口号
    static func postAutomationServerDidStart(port: Int) {
        NotificationCenter.default.post(
            name: .automationServerDidStart,
            object: nil,
            userInfo: ["port": port]
        )
    }

    /// 发送自动化服务器停止的通知
    static func postAutomationServerDidStop() {
        NotificationCenter.default.post(name: .automationServerDidStop, object: nil)
    }

    /// 发送接收到自动化动作的通知
    /// - Parameters:
    ///   - action: 动作名称
    ///   - payload: 可选的附加参数
    static func postAutomationActionReceived(action: String, payload: [String: Any]? = nil) {
        NotificationCenter.default.post(
            name: .automationActionReceived,
            object: nil,
            userInfo: ["action": action, "payload": payload as Any]
        )
    }
}

// MARK: - View Extensions for Automation Events

extension View {
    /// 监听自动化动作请求的事件
    /// - Parameter action: 事件处理闭包，参数为 (action: String, payload: [String: Any]?)
    /// - Returns: 修改后的视图
    func onAutomationAction(perform action: @escaping (String, [String: Any]?) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .automationActionReceived)) { notification in
            guard let userInfo = notification.userInfo,
                  let actionName = userInfo["action"] as? String else {
                return
            }
            let payload = userInfo["payload"] as? [String: Any]
            action(actionName, payload)
        }
    }
}

// MARK: - AutomationServer

/// 自动化测试 HTTP 服务器
///
/// 在应用启动后启动一个轻量级 HTTP 服务，监听本地端口。
/// 外部可通过网络请求传递动作指令（如模拟点击按钮），
/// 服务器收到后将指令转换为通知事件，由其他组件监听并响应。
///
/// ## 使用场景
///
/// 主要用于自动化测试场景，通过 API 触发应用内部功能。
///
/// ## API 格式
///
/// ```
/// POST http://localhost:<port>/api/action
/// Content-Type: application/json
///
/// {
///   "action": "button.click",
///   "payload": {
///     "buttonId": "sendButton"
///   }
/// }
/// ```
///
/// ## 响应格式
///
/// 成功：
/// ```json
/// { "status": "ok", "message": "Action dispatched" }
/// ```
///
/// 失败：
/// ```json
/// { "status": "error", "message": "Error description" }
/// ```
///
/// ## 集成方式
///
/// 1. 在 `MacAgent.applicationDidFinishLaunching()` 中调用 `AutomationServer.shared.start()`
/// 2. 在需要的地方监听 `.automationActionReceived` 通知并作出响应
///
/// ```swift
/// // 示例：在某个组件中监听自动化动作
/// NotificationCenter.default.publisher(for: .automationActionReceived)
///     .sink { notification in
///         guard let userInfo = notification.userInfo,
///               let action = userInfo["action"] as? String else { return }
///         switch action {
///         case "button.click":
///             // 处理按钮点击
///             break
///         default:
///             break
///         }
///     }
///     .store(in: &cancellables)
/// ```
final class AutomationServer: @unchecked Sendable, SuperLog {
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose = true

    // MARK: - Singleton

    /// 共享实例
    static let shared = AutomationServer()

    // MARK: - Configuration

    /// 默认监听端口
    static let defaultPort: UInt16 = 18765

    /// 端口被占用时的最大尝试次数。
    static let maxPortBindAttempts = 10

    /// 是否启用服务器（可通过环境变量控制）
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["LUMI_AUTOMATION_SERVER"] != "false"
    }

    // MARK: - Properties

    /// 网络监听器
    private var listener: NWListener?

    /// 连接数组（用于保持连接活跃）
    private var connections: [NWConnection] = []

    /// 当前监听的端口
    private var port: UInt16 = defaultPort

    /// 服务器是否正在运行
    var isRunning: Bool {
        listener?.state == .ready
    }

    // MARK: - Logger

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.coffic.lumi",
        category: "automation.server"
    )

    private init() {}

    // MARK: - Lifecycle

    /// 启动自动化服务器
    ///
    /// - Parameter port: 首选监听端口，默认使用 `defaultPort`
    func start(port: UInt16 = defaultPort) {
        guard Self.isEnabled else {
            Self.logger.info("\(Self.t)Automation server is disabled via environment variable")
            return
        }

        guard listener == nil || listener?.state == .cancelled else {
            Self.logger.warning("\(Self.t)Automation server is already running")
            return
        }

        start(preferredPorts: Self.candidatePorts(preferredPort: port))
    }

    /// 返回首选端口及后续备用端口。
    static func candidatePorts(preferredPort: UInt16, maxAttempts: Int = maxPortBindAttempts) -> [UInt16] {
        guard maxAttempts > 0 else { return [] }
        return (0..<maxAttempts).compactMap { offset in
            let candidate = Int(preferredPort) + offset
            guard candidate <= Int(UInt16.max) else { return nil }
            return UInt16(candidate)
        }
    }

    private func start(preferredPorts ports: [UInt16]) {
        guard let port = ports.first else {
            Self.logger.error("\(Self.t)Failed to create listener: no candidate ports available")
            return
        }

        self.port = port

        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            startNextCandidate(afterFailureOn: port, remainingPorts: Array(ports.dropFirst()), error: error)
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                Self.logger.info("\(Self.t)Automation server started on port \(self?.port ?? 0)")
                Task { @MainActor in
                    NotificationCenter.postAutomationServerDidStart(port: Int(self?.port ?? 0))
                }
            case .failed(let error):
                self?.listener = nil
                self?.startNextCandidate(afterFailureOn: port, remainingPorts: Array(ports.dropFirst()), error: error)
            case .cancelled:
                Self.logger.info("\(Self.t)Automation server stopped")
                Task { @MainActor in
                    NotificationCenter.postAutomationServerDidStop()
                }
                self?.listener = nil
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    private func startNextCandidate(afterFailureOn port: UInt16, remainingPorts: [UInt16], error: Error) {
        guard !remainingPorts.isEmpty else {
            Self.logger.error("\(Self.t)Automation server failed on port \(port): \(error.localizedDescription)")
            return
        }

        Self.logger.warning(
            "\(Self.t)Automation server could not bind port \(port): \(error.localizedDescription). Trying next port."
        )
        start(preferredPorts: remainingPorts)
    }

    /// 停止自动化服务器
    func stop() {
        guard listener?.state != .cancelled else {
            return
        }
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener = nil
    }

    // MARK: - Connection Handling

    /// 处理新的网络连接
    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        let connectionId = ObjectIdentifier(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(on: connection)
            case .cancelled, .failed:
                self?.connections.removeAll { ObjectIdentifier($0) == connectionId }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    /// 从连接接收数据
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let error {
                Self.logger.warning("\(Self.t)Receive error: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            if isComplete {
                connection.cancel()
                return
            }

            guard let content, !content.isEmpty else {
                connection.cancel()
                return
            }

            // 在主线程上处理请求（因为可能需要更新 UI）
            Task { @MainActor in
                guard let self else { return }
                let response = self.handleRequest(content)
                self.send(response: response, on: connection)
            }
        }
    }

    /// 发送响应
    private func send(response: Data, on connection: NWConnection) {
        connection.send(content: response, completion: .contentProcessed { [weak self] error in
            if let error {
                Self.logger.warning("\(Self.t)Send error: \(error.localizedDescription)")
            }
            self?.receiveData(on: connection)
        })
    }

    // MARK: - Request Handling

    /// 处理 HTTP 请求
    ///
    /// 解析简单的 HTTP POST 请求，提取 JSON body 并分发事件。
    /// 这是一个轻量级实现，仅支持 POST /api/action 路径。
    ///
    /// - Parameter data: 原始请求数据
    /// - Returns: 响应数据
    @MainActor
    private func handleRequest(_ data: Data) -> Data {
        guard let requestString = String(data: data, encoding: .utf8) else {
            return makeResponse(statusCode: 400, message: "Invalid request encoding")
        }

        // 解析 HTTP 请求行和头部
        let components = requestString.components(separatedBy: "\r\n\r\n")
        guard !components.isEmpty else {
            return makeResponse(statusCode: 400, message: "Malformed request")
        }

        let headPart = components[0]
        let bodyPart = components.count > 1 ? components[1] : ""

        // 解析请求行
        let lines = headPart.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return makeResponse(statusCode: 400, message: "Missing request line")
        }

        let parts = requestLine.components(separatedBy: " ")
        guard parts.count >= 2 else {
            return makeResponse(statusCode: 400, message: "Invalid request line")
        }

        let method = parts[0]
        let path = parts[1]

        // 只处理 POST /api/action
        guard method == "POST", path == "/api/action" || path == "/api/action/" else {
            return makeResponse(statusCode: 404, message: "Not found. Use POST /api/action")
        }

        // 解析 JSON body
        guard let bodyData = bodyPart.data(using: .utf8) else {
            return makeResponse(statusCode: 400, message: "Invalid body encoding")
        }

        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
                return makeResponse(statusCode: 400, message: "Invalid JSON: expected object")
            }

            guard let action = jsonObject["action"] as? String, !action.isEmpty else {
                return makeResponse(statusCode: 400, message: "Missing required field: action")
            }

            let payload = jsonObject["payload"] as? [String: Any]

            Self.logger.info("\(Self.t)Received automation action: \(action, privacy: .public)")

            if action == "project.debug_state" || action == "projectDebugState" {
                return makeJSONResponse(statusCode: 200, body: projectDebugStateBody())
            }

            if action == "automation.debug_state" || action == "automationDebugState" {
                return makeJSONResponse(statusCode: 200, body: automationDebugStateBody())
            }

            // 分发事件（在主线程上，以便 UI 组件可以响应）
            // 已在 Task { @MainActor } 中调用
            NotificationCenter.postAutomationActionReceived(action: action, payload: payload)

            return makeResponse(statusCode: 200, message: "Action dispatched")
        } catch {
            return makeResponse(statusCode: 400, message: "JSON parse error: \(error.localizedDescription)")
        }
    }

    /// 创建 HTTP 响应
    ///
    /// - Parameters:
    ///   - statusCode: HTTP 状态码
    ///   - message: 响应消息
    /// - Returns: 完整的 HTTP 响应数据
    private func makeResponse(statusCode: Int, message: String) -> Data {
        let bodyDict: [String: String] = [
            "status": statusCode == 200 ? "ok" : "error",
            "message": message,
        ]
        return makeJSONResponse(statusCode: statusCode, body: bodyDict)
    }

    private func makeJSONResponse(statusCode: Int, body: [String: Any]) -> Data {
        let statusText = statusCode == 200 ? "OK" : "Bad Request"
        let bodyData = try? JSONSerialization.data(withJSONObject: body)
        let body = bodyData ?? Data()

        let header = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
            + "Content-Type: application/json\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Connection: keep-alive\r\n"
            + "\r\n"

        var response = header.data(using: .utf8) ?? Data()
        response.append(body)
        return response
    }

    @MainActor
    private func projectDebugStateBody() -> [String: Any] {
        let container = RootContainer.shared.windowManagerVM.activeWindowContainer
        return [
            "status": "ok",
            "windowId": container?.id.uuidString ?? "",
            "projectSelected": container?.isProjectSelected ?? false,
            "projectName": container?.projectName ?? "",
            "projectPath": container?.projectPath ?? "",
            "activePanel": container?.layoutVM.activeViewContainerIcon ?? "",
        ]
    }

    @MainActor
    private func automationDebugStateBody() -> [String: Any] {
        let state = InlinePreviewAutomationState.shared
        return [
            "status": "ok",
            "lastSessionActionName": state.lastSessionActionName ?? "",
            "editorPanelActivationCount": state.editorPanelActivationCount,
            "inlinePreviewTabActivationCount": state.inlinePreviewTabActivationCount,
            "demoFrameRequestCount": state.demoFrameRequestCount,
            "lastDemoFramePayload": state.lastDemoFramePayload,
            "previewSessionStatus": state.previewSessionStatus,
            "previewEntryStatus": state.previewEntryStatus,
            "previewModeName": state.previewModeName,
            "previewActiveFilePath": state.previewActiveFilePath,
            "previewHasSource": state.previewHasSource,
            "previewAvailablePreviewCount": state.previewAvailablePreviewCount,
            "previewSelectedIndex": state.previewSelectedIndex,
            "previewHasCurrentFrame": state.previewHasCurrentFrame,
            "previewReceivedFrameCount": state.previewReceivedFrameCount,
            "previewLastFrameSeq": state.previewLastFrameSeq,
            "previewLastBuildTitle": state.previewLastBuildTitle,
            "previewLastBuildPreviewCount": state.previewLastBuildPreviewCount,
            "previewLastBuildUsedCache": state.previewLastBuildUsedCache,
            "previewEntryDebugState": state.previewEntryDebugState,
            "previewLastBuildLogPath": state.previewLastBuildLogPath,
        ]
    }
}

// MARK: - AutomationAction (便捷枚举)

/// 预定义的自动化动作标识符
///
/// 提供类型安全的动作名称，避免字符串拼写错误。
/// 各个组件在监听自动化动作时可以使用这些常量进行匹配。
enum AutomationAction: String {
    // MARK: - 按钮操作

    /// 模拟按钮点击
    /// payload: ["buttonId": String]
    case buttonClick = "button.click"

    /// 模拟菜单项选择
    /// payload: ["menuId": String]
    case menuSelect = "menu.select"

    // MARK: - 导航操作

    /// 切换到指定页面
    /// payload: ["page": String]
    case navigateTo = "navigate.to"

    // MARK: - 输入操作

    /// 在输入框中输入文本
    /// payload: ["inputId": String, "text": String]
    case inputText = "input.text"

    /// 提交表单
    /// payload: ["formId": String]
    case submitForm = "form.submit"

    // MARK: - 项目操作

    /// 打开项目
    /// payload: ["path": String]
    case openProject = "project.open"

    /// 创建新项目
    /// payload: ["name": String, "path": String]
    case createProject = "project.create"

    // MARK: - 对话操作

    /// 发送消息
    /// payload: ["content": String, "conversationId": String?]
    case sendMessage = "message.send"

    /// 新建对话
    case newConversation = "conversation.new"

    // MARK: - 系统操作

    /// 打开设置
    case openSettings = "settings.open"

    /// 检查更新
    case checkUpdate = "update.check"

    // MARK: - 匹配方法

    /// 从字符串创建动作
    /// - Parameter rawValue: 动作字符串
    init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }
}
