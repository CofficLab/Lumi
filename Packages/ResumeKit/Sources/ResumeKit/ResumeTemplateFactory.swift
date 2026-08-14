import Foundation

/// 内置简历模板工厂。
///
/// 每套模板都是一份完整的确定性 HTML 文档，由一个或多个
/// `.resume-page` 容器组成——每个容器的尺寸精确等于纸张预设的
/// CSS 像素尺寸，页边距内建在容器 padding 中，这是导出与打印
/// 确定性分页的基础。
public enum ResumeTemplateFactory {
    public static func html(title: String, template: ResumeTemplateKind, paper: ResumePaperKind) -> String {
        let preset = ResumePaperSpec.preset(for: paper)
        switch template {
        case .classic: return classic(title: title, preset: preset)
        case .modern: return modern(title: title, preset: preset)
        case .minimal: return minimal(title: title, preset: preset)
        case .blank: return blank(preset: preset)
        }
    }

    // MARK: - Classic

    private static func classic(title: String, preset: ResumePaperPreset) -> String {
        let name = escapeHTML(title.isEmpty ? "Your Name" : title)
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>\(name) — Resume</title>
          <style>\(sharedCSS(preset))
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: #1a1a1a; }
            .header { text-align: center; border-bottom: 2px solid #1a1a1a; padding-bottom: 14px; margin-bottom: 18px; }
            .header h1 { margin: 0; font-size: 30px; letter-spacing: .5px; }
            .contact { margin-top: 6px; font-size: 11.5px; color: #444; }
            h2 { font-size: 13px; text-transform: uppercase; letter-spacing: 1.5px; border-bottom: 1px solid #ccc; padding-bottom: 3px; margin: 16px 0 8px; }
            .entry { margin-bottom: 10px; break-inside: avoid; page-break-inside: avoid; }
            .entry-head { display: flex; justify-content: space-between; align-items: baseline; }
            .entry-title { font-weight: 700; font-size: 13.5px; }
            .entry-meta { font-size: 11.5px; color: #555; }
            ul { margin: 4px 0 0; padding-left: 18px; }
            li { font-size: 12.5px; line-height: 1.55; margin-bottom: 2px; }
          </style>
        </head>
        <body>
          <section class="resume-page" data-page="1">
            <header class="header" data-block="header" data-block-label="姓名与联系方式">
              <h1>\(name)</h1>
              <div class="contact">City · phone@example.com · (555) 010-0100 · linkedin.com/in/yourname</div>
            </header>
            <section data-block="summary" data-block-label="个人摘要">
              <h2>Summary</h2>
              <p style="font-size: 12.5px; line-height: 1.55; margin: 0;">Two or three sentences describing your professional identity, years of experience and strongest domain skills.</p>
            </section>
            <section data-block="experience" data-block-label="工作经历">
              <h2>Experience</h2>
              <div class="entry">
                <div class="entry-head"><span class="entry-title">Senior Engineer — Example Corp</span><span class="entry-meta">2022 – Present</span></div>
                <ul>
                  <li>Led a team delivering a flagship feature that increased retention by 18%.</li>
                  <li>Designed a service architecture handling 10k requests per second.</li>
                </ul>
              </div>
              <div class="entry">
                <div class="entry-head"><span class="entry-title">Engineer — Startup Inc</span><span class="entry-meta">2019 – 2022</span></div>
                <ul><li>Shipped the first mobile client used by 200k monthly users.</li></ul>
              </div>
            </section>
            <section data-block="education" data-block-label="教育背景">
              <h2>Education</h2>
              <div class="entry">
                <div class="entry-head"><span class="entry-title">B.S. Computer Science — University</span><span class="entry-meta">2015 – 2019</span></div>
              </div>
            </section>
            <section data-block="skills" data-block-label="技能">
              <h2>Skills</h2>
              <p style="font-size: 12.5px; margin: 0;">Skill one · Skill two · Skill three · Skill four</p>
            </section>
          </section>
        </body>
        </html>
        """
    }

    // MARK: - Modern

    private static func modern(title: String, preset: ResumePaperPreset) -> String {
        let name = escapeHTML(title.isEmpty ? "Your Name" : title)
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>\(name) — Resume</title>
          <style>\(sharedCSS(preset))
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: #24292f; }
            .resume-page { display: flex; padding: 0; }
            .sidebar { width: 262px; flex: none; background: #2f6690; color: #fff; padding: 44px 28px; box-sizing: border-box; }
            .main { flex: 1; padding: 44px 36px 44px 32px; box-sizing: border-box; }
            .sidebar h1 { margin: 0 0 4px; font-size: 27px; line-height: 1.15; }
            .sidebar .role { font-size: 12.5px; opacity: .85; margin-bottom: 22px; }
            .sidebar h3 { font-size: 11px; text-transform: uppercase; letter-spacing: 1.6px; opacity: .75; margin: 18px 0 6px; }
            .sidebar p, .sidebar li { font-size: 11.5px; line-height: 1.6; }
            .sidebar ul { margin: 0; padding-left: 16px; }
            .main h2 { font-size: 14px; color: #2f6690; margin: 18px 0 8px; }
            .entry { margin-bottom: 12px; break-inside: avoid; page-break-inside: avoid; }
            .entry-head { display: flex; justify-content: space-between; align-items: baseline; }
            .entry-title { font-weight: 700; font-size: 13px; }
            .entry-meta { font-size: 11px; color: #6a737d; }
            ul { margin: 4px 0 0; padding-left: 18px; }
            li { font-size: 12px; line-height: 1.55; margin-bottom: 2px; }
          </style>
        </head>
        <body>
          <section class="resume-page" data-page="1">
            <aside class="sidebar" data-block="sidebar" data-block-label="侧栏（联系方式与技能）">
              <h1>\(name)</h1>
              <div class="role">Product Engineer</div>
              <h3>Contact</h3>
              <p>City<br>phone@example.com<br>(555) 010-0100<br>linkedin.com/in/yourname</p>
              <h3>Skills</h3>
              <ul>
                <li>Skill one</li>
                <li>Skill two</li>
                <li>Skill three</li>
              </ul>
              <h3>Languages</h3>
              <p>English · Mandarin</p>
            </aside>
            <main class="main">
              <section data-block="summary" data-block-label="个人摘要">
                <h2>Summary</h2>
                <p style="font-size: 12px; line-height: 1.55; margin: 0;">Two or three sentences describing your professional identity, years of experience and strongest domain skills.</p>
              </section>
              <section data-block="experience" data-block-label="工作经历">
                <h2>Experience</h2>
                <div class="entry">
                  <div class="entry-head"><span class="entry-title">Senior Engineer — Example Corp</span><span class="entry-meta">2022 – Present</span></div>
                  <ul>
                    <li>Led a team delivering a flagship feature that increased retention by 18%.</li>
                    <li>Designed a service architecture handling 10k requests per second.</li>
                  </ul>
                </div>
                <div class="entry">
                  <div class="entry-head"><span class="entry-title">Engineer — Startup Inc</span><span class="entry-meta">2019 – 2022</span></div>
                  <ul><li>Shipped the first mobile client used by 200k monthly users.</li></ul>
                </div>
              </section>
              <section data-block="education" data-block-label="教育背景">
                <h2>Education</h2>
                <div class="entry">
                  <div class="entry-head"><span class="entry-title">B.S. Computer Science — University</span><span class="entry-meta">2015 – 2019</span></div>
                </div>
              </section>
            </main>
          </section>
        </body>
        </html>
        """
    }

    // MARK: - Minimal

    private static func minimal(title: String, preset: ResumePaperPreset) -> String {
        let name = escapeHTML(title.isEmpty ? "Your Name" : title)
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>\(name) — Resume</title>
          <style>\(sharedCSS(preset))
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: #222; }
            .resume-page { padding: 64px 68px; }
            h1 { margin: 0; font-size: 34px; font-weight: 300; letter-spacing: .5px; }
            .contact { margin-top: 8px; font-size: 12px; color: #777; }
            h2 { font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 2px; margin: 30px 0 10px; }
            .entry { margin-bottom: 14px; break-inside: avoid; page-break-inside: avoid; }
            .entry-head { display: flex; justify-content: space-between; align-items: baseline; }
            .entry-title { font-weight: 600; font-size: 13.5px; }
            .entry-meta { font-size: 11.5px; color: #888; }
            p, li { font-size: 12.5px; line-height: 1.65; }
            ul { margin: 5px 0 0; padding-left: 18px; }
          </style>
        </head>
        <body>
          <section class="resume-page" data-page="1">
            <header data-block="header" data-block-label="姓名与联系方式">
              <h1>\(name)</h1>
              <div class="contact">City · phone@example.com · linkedin.com/in/yourname</div>
            </header>
            <section data-block="summary" data-block-label="个人摘要">
              <h2>Summary</h2>
              <p style="margin: 0;">Two or three sentences describing your professional identity, years of experience and strongest domain skills.</p>
            </section>
            <section data-block="experience" data-block-label="工作经历">
              <h2>Experience</h2>
              <div class="entry">
                <div class="entry-head"><span class="entry-title">Senior Engineer — Example Corp</span><span class="entry-meta">2022 – Present</span></div>
                <ul>
                  <li>Led a team delivering a flagship feature that increased retention by 18%.</li>
                  <li>Designed a service architecture handling 10k requests per second.</li>
                </ul>
              </div>
              <div class="entry">
                <div class="entry-head"><span class="entry-title">Engineer — Startup Inc</span><span class="entry-meta">2019 – 2022</span></div>
                <ul><li>Shipped the first mobile client used by 200k monthly users.</li></ul>
              </div>
            </section>
            <section data-block="education" data-block-label="教育背景">
              <h2>Education</h2>
              <div class="entry">
                <div class="entry-head"><span class="entry-title">B.S. Computer Science — University</span><span class="entry-meta">2015 – 2019</span></div>
              </div>
            </section>
            <section data-block="skills" data-block-label="技能">
              <h2>Skills</h2>
              <p style="margin: 0;">Skill one · Skill two · Skill three · Skill four</p>
            </section>
          </section>
        </body>
        </html>
        """
    }

    // MARK: - Blank

    private static func blank(preset: ResumePaperPreset) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>Resume</title>
          <style>\(sharedCSS(preset))
            body { font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: #222; }
            .entry { break-inside: avoid; page-break-inside: avoid; }
          </style>
        </head>
        <body>
          <section class="resume-page" data-page="1">
            <!-- Build the resume freely. Keep every page inside a .resume-page container. -->
          </section>
        </body>
        </html>
        """
    }

    // MARK: - Shared

    /// 所有模板共享的分页与打印约定。
    private static func sharedCSS(_ preset: ResumePaperPreset) -> String {
        """
            * { box-sizing: border-box; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
            html, body { margin: 0; padding: 0; background: #fff; }
            body { display: flex; flex-direction: column; align-items: center; }
            .resume-page {
              position: relative;
              width: \(preset.cssWidth)px;
              height: \(preset.cssHeight)px;
              flex: none;
              overflow: hidden;
              background: #fff;
            }
            .resume-page + .resume-page { page-break-before: always; break-before: page; }
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
