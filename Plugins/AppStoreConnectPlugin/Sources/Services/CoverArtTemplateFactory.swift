import Foundation

enum CoverArtTemplateFactory {
    static func html(title: String, displayType: String, size: ScreenshotDisplaySpec.Size) -> String {
        let escapedTitle = escapeHTML(title.isEmpty ? "App Title" : title)
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=\(size.width), height=\(size.height)" />
          <title>\(escapedTitle)</title>
          <style>
            html, body {
              margin: 0;
              width: \(size.width)px;
              height: \(size.height)px;
              overflow: hidden;
              font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif;
            }
            body {
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              gap: 48px;
              background: linear-gradient(180deg, #f5f5f7 0%, #e8e8ed 100%);
              color: #1d1d1f;
            }
            .icon {
              width: \(Int(Double(size.width) * 0.28))px;
              height: \(Int(Double(size.width) * 0.28))px;
              border-radius: 22%;
              background: #ffffff;
              box-shadow: 0 24px 60px rgba(0, 0, 0, 0.12);
              display: flex;
              align-items: center;
              justify-content: center;
              font-size: \(Int(Double(size.width) * 0.12))px;
            }
            h1 {
              margin: 0;
              padding: 0 64px;
              font-size: \(Int(Double(size.width) * 0.055))px;
              font-weight: 700;
              text-align: center;
              line-height: 1.15;
            }
          </style>
        </head>
        <body data-display-type="\(displayType)">
          <div class="icon" aria-hidden="true">★</div>
          <h1>\(escapedTitle)</h1>
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
