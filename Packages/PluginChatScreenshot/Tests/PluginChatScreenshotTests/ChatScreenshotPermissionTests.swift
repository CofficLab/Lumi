import Testing
@testable import PluginChatScreenshot

// MARK: - Screen Recording 权限

@Suite("Chat Screenshot 权限请求")
@MainActor
struct ChatScreenshotPermissionTests {

    @Test("未授权时触发系统授权请求并采用其结果")
    func requestsSystemPromptWhenNotAuthorized() {
        var requested = false

        let granted = ScreenCapturePermissionPrompter.ensurePermission(
            preflight: { false },
            request: {
                requested = true
                return true
            }
        )

        #expect(granted)
        #expect(requested)
    }

    @Test("已授权时不再触发系统授权请求")
    func skipsRequestWhenAlreadyAuthorized() {
        var requested = false

        let granted = ScreenCapturePermissionPrompter.ensurePermission(
            preflight: { true },
            request: {
                requested = true
                return false
            }
        )

        #expect(granted)
        #expect(requested == false)
    }

    @Test("用户拒绝授权时返回 false，交由调用方引导设置")
    func returnsFalseWhenRequestDenied() {
        let granted = ScreenCapturePermissionPrompter.ensurePermission(
            preflight: { false },
            request: { false }
        )

        #expect(granted == false)
    }
}
