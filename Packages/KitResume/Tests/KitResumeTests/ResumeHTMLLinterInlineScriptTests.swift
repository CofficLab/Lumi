import Foundation
import Testing
@testable import KitResume

/// 「无脚本」契约必须覆盖内联事件处理器与 javascript: URL（#494）。
///
/// 旧 linter 只拦 `<script>`/iframe/远程资源，`<body onload=…>` 能通过校验，
/// 但预览（修复前）会执行它而导出不会，呈现不同 DOM。修复后 linter 直接拒绝。
@Suite("ResumeHTMLLinter inline script (#494)")
struct ResumeHTMLLinterInlineScriptTests {

    /// 一份满足其余全部规则的合法简历 HTML，便于隔离内联脚本这一条断言。
    private func validHTML(body: String) -> String {
        """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          .resume-page { width: 794px; height: 1123px; overflow: hidden; background: #fff; }
          .entry { break-inside: avoid; }
        </style>
        </head><body>\(body)</body></html>
        """
    }

    @Test("内联事件处理器被拒绝")
    func rejectsInlineEventHandler() {
        let html = validHTML(body: """
        <section class="resume-page" onload="document.title='JS_RAN'"><p class="entry">Ada</p></section>
        """)
        let report = ResumeHTMLLinter().lint(html: html)
        #expect(report.errors.contains { $0.code == "inline_script_forbidden" })
        #expect(!report.isValid)
    }

    @Test("任意标签上的事件处理器都被拒绝")
    func rejectsEventHandlerOnInnerTag() {
        let html = validHTML(body: """
        <section class="resume-page"><img src="photo.png" onerror="alert(1)"><p class="entry">Ada</p></section>
        """)
        let report = ResumeHTMLLinter().lint(html: html)
        #expect(report.errors.contains { $0.code == "inline_script_forbidden" })
    }

    @Test("javascript: 伪协议 URL 被拒绝")
    func rejectsJavaScriptURL() {
        let html = validHTML(body: """
        <section class="resume-page"><a href="javascript:alert(1)">link</a><p class="entry">Ada</p></section>
        """)
        let report = ResumeHTMLLinter().lint(html: html)
        #expect(report.errors.contains { $0.code == "inline_script_forbidden" })
    }

    @Test("正文里偶然出现的 on…= 文本不被误判")
    func doesNotFlagPlainText() {
        let html = validHTML(body: """
        <section class="resume-page"><p class="entry">Turn on light=1 and focus on results.</p></section>
        """)
        let report = ResumeHTMLLinter().lint(html: html)
        #expect(!report.errors.contains { $0.code == "inline_script_forbidden" })
    }
}