import Foundation

public enum AppStorePromoTemplateFactory {
    public static func html(title: String, appName: String, family: AppStorePromoDeviceFamily) -> String {
        let headline = escapeHTML(title.isEmpty ? "A better way to work" : title)
        let name = escapeHTML(appName.isEmpty ? "Your App" : appName)
        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
          <title>\(headline)</title>
          <style>
            * { box-sizing: border-box; }
            html, body { width: 100%; height: 100%; margin: 0; overflow: hidden; }
            body {
              position: relative;
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: space-between;
              padding: 7vmin 6vmin 0;
              background: linear-gradient(155deg, #5b5ce2 0%, #8357d8 45%, #c45dc8 100%);
              color: white;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
            }
            .copy { text-align: center; max-width: 88%; }
            .eyebrow { font-size: clamp(18px, 2.2vmin, 42px); font-weight: 650; opacity: .82; }
            h1 { margin: 1.4vmin 0 0; font-size: clamp(38px, 6.2vmin, 112px); line-height: 1.04; letter-spacing: -.035em; }
            .device {
              width: min(78%, 82vmin);
              height: 68%;
              padding: 1.4vmin;
              border-radius: 5vmin 5vmin 0 0;
              background: #16161a;
              box-shadow: 0 3vmin 8vmin rgba(20, 10, 50, .34);
            }
            .screen {
              width: 100%; height: 100%; overflow: hidden;
              border-radius: 3.8vmin 3.8vmin 0 0;
              display: grid; place-items: center;
              background: linear-gradient(180deg, #fff, #eef0f7);
              color: #202027; font-size: clamp(24px, 4vmin, 76px); font-weight: 700;
            }
          </style>
        </head>
        <body data-device-family="\(family.rawValue)">
          <section class="copy" data-block="headline" data-block-label="标题文案">
            <div class="eyebrow">\(name)</div>
            <h1>\(headline)</h1>
          </section>
          <section class="device" data-block="screenshot" data-block-label="截图框" aria-label="App screenshot frame">
            <div class="screen">Add a screenshot to assets/</div>
          </section>
        </body>
        </html>
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
