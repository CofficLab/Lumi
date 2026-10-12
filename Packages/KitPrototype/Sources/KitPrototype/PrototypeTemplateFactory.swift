import Foundation

/// 原型屏幕的起始 HTML 模板工厂。
///
/// 两套模板对应 `PrototypeStyle`：`wireframe` 强调结构与信息层级（灰阶、占位块），
/// `hiFi` 提供带品牌色与圆角的拟真起点。模板必须满足 linter 的全部 error 规则：
/// 完整文档、viewport、无 script/iframe/远程资源，并带 `data-block` 标注。
///
/// 跳转不预埋 `data-prototype-link`——首屏无同伴目标时预埋会造成
/// `unknown_link_target`。模板注释里给出写法指引，由 LLM 按实际流程补上。
public enum PrototypeTemplateFactory {

    /// 生成一屏起始 HTML。
    ///
    /// - Parameters:
    ///   - title: 屏幕标题（进入 `<title>` 与可见标题位）。
    ///   - appName: 原型所属产品名，用于顶部标识；为空时用 "App"。
    ///   - style: 视觉风格。
    ///   - device: 画板设备，用于标注逻辑尺寸。
    public static func html(
        title: String,
        appName: String,
        style: PrototypeStyle,
        device: PrototypeDevice
    ) -> String {
        let screenTitle = title.isEmpty ? "Untitled Screen" : title
        let productName = appName.isEmpty ? "App" : appName
        switch style {
        case .wireframe:
            return wireframe(title: screenTitle, appName: productName, device: device)
        case .hiFi:
            return hiFi(title: screenTitle, appName: productName, device: device)
        }
    }

    // MARK: - 低保真线框图

    private static func wireframe(title: String, appName: String, device: PrototypeDevice) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; overflow: hidden; }
            body {
              display: flex;
              flex-direction: column;
              background: #f4f5f7;
              color: #2b2f36;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif;
              font-size: 14px;
            }
            /* 线框图通用占位样式：虚线边框 + 灰底，强调结构而非视觉。 */
            .box {
              border: 1px dashed #b6bcc7;
              border-radius: 8px;
              background: #ffffff;
            }
            .bar { background: #ffffff; border-bottom: 1px solid #e3e6ec; }
            header.bar {
              display: flex; align-items: center; justify-content: space-between;
              padding: 18px 16px 12px;
            }
            .brand { font-size: 17px; font-weight: 700; letter-spacing: -0.2px; }
            .avatar { width: 30px; height: 30px; border-radius: 50%; background: #dfe3ea; }
            main { flex: 1; display: flex; flex-direction: column; gap: 12px; padding: 16px; overflow: hidden; }
            .hero { flex: 0 0 auto; height: 132px; display: grid; place-items: center; }
            .hero-label { color: #8b93a1; font-size: 12px; letter-spacing: 0.4px; text-transform: uppercase; }
            .list { flex: 1; display: flex; flex-direction: column; gap: 10px; overflow: hidden; }
            .row { display: flex; align-items: center; gap: 12px; padding: 12px; }
            .thumb { width: 42px; height: 42px; border-radius: 8px; background: #e6e9ef; flex: 0 0 auto; }
            .lines { flex: 1; display: flex; flex-direction: column; gap: 6px; }
            .line { height: 8px; border-radius: 4px; background: #e6e9ef; }
            .line.short { width: 55%; }
            footer.bar {
              display: flex; align-items: center; justify-content: space-around;
              padding: 10px 8px 22px; border-top: 1px solid #e3e6ec; border-bottom: none;
            }
            .tab { display: flex; flex-direction: column; align-items: center; gap: 4px; }
            .tab .dot { width: 20px; height: 20px; border-radius: 6px; border: 1px dashed #b6bcc7; }
            .tab .caption { font-size: 10px; color: #8b93a1; }
            .action {
              position: fixed; right: 16px; bottom: 92px;
              width: 52px; height: 52px; border-radius: 26px;
              background: #2b2f36; color: #fff;
              display: grid; place-items: center; font-size: 26px; line-height: 1;
            }
          </style>
        </head>
        <body data-device="\(escapeHTML(device.kind.rawValue))" data-logical-width="\(Int(device.width))" data-logical-height="\(Int(device.height))">
          <!-- 低保真线框图：结构清晰、视觉中性，用于验证信息层级与流程。
               跳转写法：在需要跳转的控件上加 data-prototype-link="目标屏-slug"
               以及可选的 data-prototype-label="按钮文案"。不要写 script。 -->
          <header class="bar" \(blockAttributes("header", "顶部栏"))>
            <div class="brand">\(escapeHTML(appName))</div>
            <div class="avatar"></div>
          </header>

          <main>
            <section class="box hero" \(blockAttributes("hero", "主视觉区"))>
              <span class="hero-label">Hero / 主视觉</span>
            </section>

            <section class="list" \(blockAttributes("list", "列表"))>
              <article class="box row">
                <div class="thumb"></div>
                <div class="lines">
                  <div class="line"></div>
                  <div class="line short"></div>
                </div>
              </article>
              <article class="box row">
                <div class="thumb"></div>
                <div class="lines">
                  <div class="line"></div>
                  <div class="line short"></div>
                </div>
              </article>
              <article class="box row">
                <div class="thumb"></div>
                <div class="lines">
                  <div class="line"></div>
                  <div class="line short"></div>
                </div>
              </article>
            </section>
          </main>

          <div class="action" \(blockAttributes("primary-action", "主操作"))>+</div>

          <footer class="bar" \(blockAttributes("tabbar", "底部标签栏"))>
            <div class="tab"><div class="dot"></div><span class="caption">首页</span></div>
            <div class="tab"><div class="dot"></div><span class="caption">浏览</span></div>
            <div class="tab"><div class="dot"></div><span class="caption">我的</span></div>
          </footer>
        </body>
        </html>
        """
    }

    // MARK: - 高保真

    private static func hiFi(title: String, appName: String, device: PrototypeDevice) -> String {
        """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>\(escapeHTML(title))</title>
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body { width: 100%; height: 100%; overflow: hidden; }
            body {
              display: flex;
              flex-direction: column;
              background: #ffffff;
              color: #10131a;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
            }
            header {
              padding: 20px 20px 16px;
              display: flex; align-items: center; justify-content: space-between;
              background: linear-gradient(150deg, #4f46e5 0%, #7c3aed 60%, #a855f7 100%);
              color: #fff;
            }
            .eyebrow { font-size: 11px; font-weight: 600; letter-spacing: 0.8px; text-transform: uppercase; opacity: 0.85; }
            h1 { font-size: 24px; font-weight: 700; letter-spacing: -0.5px; margin-top: 4px; }
            .avatar {
              width: 36px; height: 36px; border-radius: 18px;
              background: rgba(255, 255, 255, 0.22); flex: 0 0 auto;
            }
            main { flex: 1; padding: 18px 20px; display: flex; flex-direction: column; gap: 14px; overflow: hidden; }
            .card {
              border-radius: 16px; padding: 16px; background: #f7f8fb;
              border: 1px solid #eceef4;
            }
            .card.highlight {
              background: linear-gradient(160deg, #eef2ff 0%, #faf5ff 100%);
              border-color: #e0e4ff;
            }
            .card h2 { font-size: 15px; font-weight: 650; }
            .card p { font-size: 13px; line-height: 1.45; color: #5b6270; margin-top: 6px; }
            .stat-row { display: flex; gap: 12px; }
            .stat { flex: 1; }
            .stat .value { font-size: 22px; font-weight: 700; letter-spacing: -0.6px; }
            .stat .label { font-size: 11px; color: #6b7280; margin-top: 2px; }
            .cta {
              margin-top: auto; height: 50px; border-radius: 25px;
              background: #4f46e5; color: #fff;
              display: grid; place-items: center;
              font-size: 16px; font-weight: 650;
              box-shadow: 0 10px 22px rgba(79, 70, 229, 0.28);
            }
            .chips { display: flex; gap: 8px; flex-wrap: wrap; }
            .chip {
              font-size: 12px; padding: 6px 12px; border-radius: 999px;
              background: #eef0f6; color: #4b5563;
            }
          </style>
        </head>
        <body data-device="\(escapeHTML(device.kind.rawValue))" data-logical-width="\(Int(device.width))" data-logical-height="\(Int(device.height))">
          <!-- 高保真原型：带品牌色与真实排版，用于评审视觉与文案。
               跳转写法：在需要跳转的控件上加 data-prototype-link="目标屏-slug"
               以及可选的 data-prototype-label="按钮文案"。不要写 script。 -->
          <header \(blockAttributes("header", "顶部栏"))>
            <div>
              <div class="eyebrow">\(escapeHTML(appName))</div>
              <h1>\(escapeHTML(title))</h1>
            </div>
            <div class="avatar"></div>
          </header>

          <main>
            <section class="card highlight" \(blockAttributes("summary", "概览卡片"))>
              <h2>概览</h2>
              <p>用一句话说明这一屏要解决的问题。</p>
            </section>

            <section class="card" \(blockAttributes("metrics", "数据卡片"))>
              <div class="stat-row">
                <div class="stat"><div class="value">12</div><div class="label">指标 A</div></div>
                <div class="stat"><div class="value">86%</div><div class="label">指标 B</div></div>
                <div class="stat"><div class="value">4.8</div><div class="label">指标 C</div></div>
              </div>
            </section>

            <section \(blockAttributes("filters", "筛选项"))>
              <div class="chips">
                <span class="chip">全部</span>
                <span class="chip">进行中</span>
                <span class="chip">已完成</span>
              </div>
            </section>

            <section class="card" \(blockAttributes("list", "内容列表"))>
              <h2>列表标题</h2>
              <p>补充说明这一组内容。</p>
            </section>

            <div class="cta" \(blockAttributes("primary-action", "主操作"))>开始</div>
          </main>
        </body>
        </html>
        """
    }

    // MARK: - 辅助

    /// 生成 `data-block` / `data-block-label` 标注属性。
    private static func blockAttributes(_ blockID: String, _ label: String) -> String {
        "\(PrototypeHTMLAttributes.block)=\"\(blockID)\" \(PrototypeHTMLAttributes.blockLabel)=\"\(label)\""
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
