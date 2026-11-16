import Foundation
import Testing
@testable import PluginConversationTitle

/// Regression coverage for #783: the injected `<system-reminder>` cleanup only
/// stripped a block that started at the very first character. A leading newline
/// or space (IDE clients inject one before the reminder), or a blank line between
/// consecutive reminders, defeated the cleanup, so the XML noise filled the
/// 40-character placeholder title and was persisted while the real request was
/// cut off. Leading/inter-block whitespace must be skipped, while a reminder in
/// the middle of the user's own text stays untouched.
@Suite("开头注入提醒块的空白清理 (#783)")
struct InjectedReminderWhitespaceTests {

    @Test("placeholderTitle：前导换行后的提醒块仍被去掉")
    func stripsReminderAfterLeadingNewline() {
        let text = "\n<system-reminder>Xcode</system-reminder>\n\nRefactor this Swift code"
        let result = AutoConversationTitleService.placeholderTitle(forFirstUserMessage: text)
        #expect(result == "Refactor this Swift code")
        #expect(!result.contains("system-reminder"))
    }

    @Test("placeholderTitle：前导空格后的提醒块仍被去掉")
    func stripsReminderAfterLeadingSpaces() {
        let text = "   <system-reminder>env</system-reminder>  Real request"
        let result = AutoConversationTitleService.placeholderTitle(forFirstUserMessage: text)
        #expect(result == "Real request")
    }

    @Test("placeholderTitle：空行分隔的连续提醒块全部被去掉")
    func stripsConsecutiveRemindersSeparatedByBlankLine() {
        let text = "<system-reminder>A</system-reminder>\n\n<system-reminder>B</system-reminder>\n\nReal request"
        let result = AutoConversationTitleService.placeholderTitle(forFirstUserMessage: text)
        #expect(result == "Real request")
        #expect(!result.contains("system-reminder"))
    }

    @Test("strippingInjectedReminders：跳过前导与块间空白，逐块剥离到真实内容")
    func strippingHelperSkipsLeadingAndInterBlockWhitespace() {
        let text = "\n\n<system-reminder>A</system-reminder>\n<system-reminder>B</system-reminder>\nTail"
        let stripped = AutoConversationTitleService.strippingInjectedReminders(text)
        #expect(!stripped.contains("system-reminder"))
        #expect(stripped.contains("Tail"))
    }

    @Test("边界：前导空白后是真实正文时，中间的同名标签保留不动")
    func keepsInnerReminderAfterLeadingWhitespaceAndRealText() {
        let text = "  \nHello <system-reminder>x</system-reminder> world"
        // 开头不是提醒块（先有正文 Hello），中间的标签是用户内容，必须原样保留。
        #expect(AutoConversationTitleService.strippingInjectedReminders(text) == text)
        let placeholder = AutoConversationTitleService.placeholderTitle(forFirstUserMessage: text)
        #expect(placeholder.hasPrefix("Hello"))
        #expect(placeholder.contains("<system-reminder>"))
    }

    @Test("无提醒块时前导空白不被误删（交由后续折叠处理）")
    func leavesLeadingWhitespaceWhenNoReminder() {
        let text = "  \nJust a normal request"
        #expect(AutoConversationTitleService.strippingInjectedReminders(text) == text)
        #expect(AutoConversationTitleService.placeholderTitle(forFirstUserMessage: text) == "Just a normal request")
    }
}