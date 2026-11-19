import Foundation

/// `browser_read` 的正文与交互控件采集脚本。
///
/// ref 策略与快照一致（#1091）：ref 必须由 Lumi 分配，编号取自 window 上
/// 持久化的同一计数器。不能按枚举下标从 `lumi-1` 重新编号（#268）——
/// 那会与既有 ref 撞号，把旧 ref 静默重映射到别的控件；改用共享计数器后
/// 编号只增不复用，旧 ref 失效时交互侧会明确报 STALE_REF 而不是误操作。
enum BrowserReadPageScript {
    static func script(maxCharacters: Int) -> String {
        """
        (() => {
          const STATE = (window.__lumiBrowserState = window.__lumiBrowserState || { counter: 0 });
          const text = document.body ? document.body.innerText : "";
          return {
            title: document.title || "",
            url: location.href,
            text: text.slice(0, \(maxCharacters)),
            truncated: text.length > \(maxCharacters),
            controls: Array.from(document.querySelectorAll("a[href],button,input,textarea,select,[role=button]"))
              .filter(el => el.getClientRects().length > 0)
              .slice(0, 80)
              .map((el) => {
                STATE.counter += 1;
                const ref = "lumi-" + STATE.counter;
                el.setAttribute("data-lumi-browser-ref", ref);
                const label = el.getAttribute("aria-label") || el.innerText || el.getAttribute("placeholder") || el.getAttribute("title") || "";
                let href = el.tagName === "A" ? el.href : "";
                if (href) {
                  try {
                    const link = new URL(href);
                    for (const key of ["token", "access_token", "api_key", "key", "password", "secret", "code"]) {
                      if (link.searchParams.has(key)) link.searchParams.set(key, "[redacted]");
                    }
                    href = link.href;
                  } catch (_) {}
                }
                return { ref, tag: el.tagName.toLowerCase(), type: el.getAttribute("type") || "", label: label.trim().replace(/\\s+/g, " ").slice(0, 160), href };
              })
          };
        })()
        """
    }
}
