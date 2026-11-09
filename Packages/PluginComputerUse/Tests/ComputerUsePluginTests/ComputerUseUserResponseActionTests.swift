import Foundation
import KitAgentTool
import Testing
@testable import ComputerUsePlugin

/// Computer Use 授权卡片的恢复语义。
///
/// 卡片回传 `<token>\n<说明>`：允许必须重新执行工具拿到真实结果，
/// 拒绝必须以失败结束且不重执行，其它回答保持「回答即结果」。
@Suite("Computer Use 授权恢复动作")
struct ComputerUseUserResponseActionTests {

    @Test("允许标记触发重新执行")
    func allowTokenReexecutes() {
        #expect(
            computerUseUserResponseAction(
                for: "\(ComputerUseAuthorizationResolver.allowForTaskToken)\nAccess granted for this task"
            ) == .reexecute
        )
    }

    @Test("拒绝标记以说明文案失败结束")
    func denyTokenRejectsWithMessage() {
        #expect(
            computerUseUserResponseAction(
                for: "\(ComputerUseAuthorizationResolver.denyToken)\nThe user denied access"
            ) == .reject(reason: "The user denied access")
        )
    }

    @Test("无法识别的回答保持文本返回")
    func unknownAnswerReturnsText() {
        #expect(computerUseUserResponseAction(for: "再看看这个窗口") == .returnAnswer)
    }

    @Test("四个挂起工具都通过存在类型暴露恢复动作")
    func toolsDeclareResumeActionThroughExistential() {
        // 避开 `.shared`：它会经由授权存储触碰运行时目录。
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ComputerUseResumeAction-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = ComputerUseService(
            authorizationStore: ComputerUseAuthorizationStore(dataDirectory: directory)
        )

        let tools: [any SuperAgentTool] = [
            ComputerObserveV2Tool(service: service),
            ComputerActV2Tool(service: service),
            AccessibilityObserveTool(),
            AccessibilityActTool(),
        ]
        for tool in tools {
            #expect(
                tool.userResponseAction(
                    for: "\(ComputerUseAuthorizationResolver.allowForTaskToken)\ngranted",
                    arguments: [:]
                ) == .reexecute,
                "\(tool.name) 授权后必须重新执行"
            )
            #expect(
                tool.userResponseAction(
                    for: "\(ComputerUseAuthorizationResolver.denyToken)\ndenied",
                    arguments: [:]
                ) == .reject(reason: "denied"),
                "\(tool.name) 拒绝后不能重新执行"
            )
            #expect(
                tool.userResponseAction(for: "随便聊聊", arguments: [:]) == .returnAnswer,
                "\(tool.name) 非授权回答保持文本返回"
            )
        }
    }
}
